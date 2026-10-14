#!/usr/bin/env dart
/// Build Enforcer - Ensures project builds and tests pass after every operation.
///
/// Usage:
///   dart run tool/build_enforcer.dart [--fix] [--test] [--build] [--analyze]
///
/// Options:
///   --fix       Attempt to auto-fix common issues (format, imports, etc.)
///   --test      Run tests (default: true)
///   --build     Run build for current platform (default: true)
///   --analyze   Run static analysis (default: true)
///   --watch     Watch mode - re-run on file changes
///   --verbose   Verbose output

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

class BuildEnforcer {
  final bool autoFix;
  final bool runTests;
  final bool runBuild;
  final bool runAnalyze;
  final bool watchMode;
  final bool verbose;
  final String projectRoot;

  BuildEnforcer({
    required this.autoFix,
    required this.runTests,
    required this.runBuild,
    required this.runAnalyze,
    required this.watchMode,
    required this.verbose,
    required this.projectRoot,
  });

  Future<int> run() async {
    if (watchMode) {
      return _runWatchMode();
    }
    return _runOnce();
  }

  Future<int> _runOnce() async {
    var exitCode = 0;

    if (runAnalyze) {
      final result = await _runAnalyze();
      if (result != 0) exitCode = result;
    }

    if (runTests) {
      final result = await _runTests();
      if (result != 0) exitCode = result;
    }

    if (runBuild) {
      final result = await _runBuild();
      if (result != 0) exitCode = result;
    }

    if (exitCode == 0) {
      _log('✅ All checks passed!');
    } else {
      _log('❌ Some checks failed (exit code: $exitCode)');
    }

    return exitCode;
  }

  Future<int> _runWatchMode() async {
    _log('🔍 Watch mode enabled - monitoring for changes...');
    // Use `dart run build_runner watch` equivalent for our checks
    // For simplicity, we'll poll for file changes
    final watchedDirs = [
      'lib',
      'test',
      'tool',
    ];

    final lastModified = <String, DateTime>{};

    while (true) {
      bool changed = false;
      for (final dir in watchedDirs) {
        final fullDir = p.join(projectRoot, dir);
        if (!await Directory(fullDir).exists()) continue;
        await for (final entity in Directory(fullDir).list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            final last = lastModified[entity.path];
            if (last == null || stat.modified.isAfter(last)) {
              lastModified[entity.path] = stat.modified;
              changed = true;
            }
          }
        }
      }

      if (changed) {
        _log('\n📝 Changes detected, running checks...');
        final result = await _runOnce();
        if (result != 0) {
          _log('⚠️ Checks failed, but continuing to watch...');
        }
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<int> _runAnalyze() async {
    _log('🔍 Running static analysis (flutter analyze)...');
    return _runCommand('flutter', ['analyze']);
  }

  Future<int> _runTests() async {
    _log('🧪 Running tests (flutter test)...');
    return _runCommand('flutter', ['test', '--reporter=expanded']);
  }

  Future<int> _runBuild() async {
    _log('🏗️ Running build (flutter build)...');
    // Determine platform
    final platform = Platform.operatingSystem;
    String buildCommand;
    switch (platform) {
      case 'windows':
        buildCommand = 'windows';
        break;
      case 'macos':
        buildCommand = 'macos';
        break;
      case 'linux':
        buildCommand = 'linux';
        break;
      default:
        // Try to build APK for mobile as fallback
        buildCommand = 'apk';
    }
    return _runCommand('flutter', ['build', buildCommand, '--no-tree-shake-icons']);
  }

  Future<int> _runCommand(String command, List<String> args) async {
    if (verbose) {
      _log('  → $command ${args.join(' ')}');
    }

    final process = await Process.start(command, args,
        workingDirectory: projectRoot,
        runInShell: true);

    final stdout = process.stdout.transform(utf8.decoder);
    final stderr = process.stderr.transform(utf8.decoder);

    stdout.listen((line) => _log('  $line', isOutput: true));
    stderr.listen((line) => _log('  $line', isError: true));

    final exitCode = await process.exitCode;

    if (exitCode != 0 && autoFix) {
      _log('  ⚠️ Command failed, attempting auto-fix...');
      await _attemptAutoFix(command, args);
      // Retry once after fix
      return _runCommand(command, args);
    }

    return exitCode;
  }

  Future<void> _attemptAutoFix(String command, List<String> args) async {
    if (command == 'flutter' && args.contains('analyze')) {
      _log('  🔧 Running dart fix --apply...');
      await _runCommand('dart', ['fix', '--apply']);
    } else if (command == 'flutter' && args.contains('test')) {
      _log('  🔧 Running flutter test with --update-goldens...');
      // Could add --update-goldens if needed
    } else if (command == 'dart' && args.contains('format')) {
      _log('  🔧 Running dart format...');
      await _runCommand('dart', ['format', '.']);
    }
  }

  void _log(String message, {bool isOutput = false, bool isError = false}) {
    if (!verbose && isOutput) return;
    if (!verbose && isError) return;

    final prefix = isError ? '❌ ' : (isOutput ? '' : '  ');
    print('$prefix$message');
  }
}

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('fix', negatable: false, help: 'Attempt to auto-fix common issues')
    ..addFlag('test', negatable: true, defaultsTo: true, help: 'Run tests')
    ..addFlag('build', negatable: true, defaultsTo: true, help: 'Run build')
    ..addFlag('analyze', negatable: true, defaultsTo: true, help: 'Run static analysis')
    ..addFlag('watch', negatable: false, help: 'Watch mode - re-run on file changes')
    ..addFlag('verbose', negatable: false, help: 'Verbose output')
    ..addFlag('help', negatable: false, abbr: 'h', help: 'Show usage');

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print(parser.usage);
    exit(0);
  }

  final projectRoot = Directory.current.path;

  final enforcer = BuildEnforcer(
    autoFix: results['fix'] as bool,
    runTests: results['test'] as bool,
    runBuild: results['build'] as bool,
    runAnalyze: results['analyze'] as bool,
    watchMode: results['watch'] as bool,
    verbose: results['verbose'] as bool,
    projectRoot: projectRoot,
  );

  final exitCode = await enforcer.run();
  exit(exitCode);
}