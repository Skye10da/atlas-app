import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges files opened *on* the OS ("Open with Atlas") into the app.
///
/// On desktop the OS hands the app the opened file path as a command-line
/// argument (surfaced through [Platform.executableArguments] by the runner's
/// `set_dart_entrypoint_arguments`). On mobile the native side copies a
/// content/file URI into the app sandbox and pushes a plain absolute path
/// over the platform channel defined here.
class FileOpenController {
  static const MethodChannel _channel = MethodChannel('com.atlasapp/file_open');

  final StreamController<String> _paths = StreamController<String>.broadcast();

  /// Paths the OS asked us to open (absolute, on-disk).
  Stream<String> get openedFiles => _paths.stream;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _initChannel();
    _emitDesktopArguments();
    await _emitInitialMobileFile();
  }

  Future<void> _initChannel() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileOpened') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          _paths.add(path);
        }
      }
    });
  }

  Future<void> _emitInitialMobileFile() async {
    try {
      final initial = await _channel.invokeMethod<String>(
        'getInitialOpenedFile',
      );
      if (initial != null && initial.isNotEmpty) {
        _paths.add(initial);
      }
    } catch (_) {
      // No native file-open handler (e.g. web) — ignore.
    }
  }

  void _emitDesktopArguments() {
    for (final arg in Platform.executableArguments) {
      final path = _supportedFilePath(arg);
      if (path != null) {
        _paths.add(path);
      }
    }
  }

  String? _supportedFilePath(String arg) {
    final lower = arg.toLowerCase();
    if (lower.endsWith('.epub') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.atlas')) {
      return arg;
    }
    return null;
  }

  void dispose() {
    _paths.close();
  }
}
