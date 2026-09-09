import 'dart:io';

// Patches real_page_flip-2.2.9 pubspec to remove broken desktop platforms
// (linux, macos, windows) that have no native implementation or cause
// CMake/CocoaPods failures on CI. Also fixes Android build.gradle.kts.

void main() async {
  final pubCacheCandidates = [
    Platform.environment['PUB_CACHE'],
    '${Platform.environment['HOME']}/.pub-cache',
    '${Platform.environment['USERPROFILE']}\\AppData\\Local\\Pub\\Cache',
    '/home/runner/.pub-cache',
    'C:\\Users\\runneradmin\\AppData\\Local\\Pub\\Cache',
  ].whereType<String>();

  String? pubCache;
  for (final c in pubCacheCandidates) {
    if (c.isEmpty) continue;
    if (Directory(c).existsSync()) {
      pubCache = c;
      break;
    }
  }
  // try flutter pub cache dir
  try {
    final res = await Process.run('flutter', ['pub', 'cache', 'dir']);
    final out = (res.stdout as String).trim();
    if (out.isNotEmpty && Directory(out).existsSync()) pubCache = out;
  } catch (_) {}

  if (pubCache == null) {
    stderr.writeln('PUB_CACHE not found');
    exit(1);
  }

  final pluginDir = Directory('$pubCache/hosted/pub.dev/real_page_flip-2.2.9');
  if (!pluginDir.existsSync()) {
    stderr.writeln('real_page_flip not found in $pubCache');
    exit(0);
  }

  // 1. Patch pubspec.yaml - keep only android, ios, web
  final pubspec = File('${pluginDir.path}/pubspec.yaml');
  if (pubspec.existsSync()) {
    var content = await pubspec.readAsString();
    final original = content;
    // Remove macos block
    content = content.replaceAll(
      RegExp(r'\n\s+macos:\n(?:.*\n){1,3}'), '\n',
    );
    content = content.replaceAll(
      RegExp(r'\n\s+windows:\n(?:.*\n){1,3}'), '\n',
    );
    content = content.replaceAll(
      RegExp(r'\n\s+linux:\n(?:.*\n){1,4}'), '\n',
    );
    if (content != original) {
      await pubspec.writeAsString(content);
      stdout.writeln('Patched pubspec.yaml (removed desktop platforms)');
    } else {
      stdout.writeln('pubspec.yaml already patched or pattern not matched');
      // fallback: rewrite with known good
      if (content.contains('RealPageFlipMacos') ||
          content.contains('RealPageFlipLinux') ||
          content.contains('windows:')) {
        stderr.writeln('Fallback rewrite');
        await pubspec.writeAsString(_patchedPubspec);
        stdout.writeln('Rewrote pubspec.yaml from template');
      }
    }
  }

  // 2. Patch Android build.gradle.kts -> build.gradle (Groovy)
  final kts = File('${pluginDir.path}/android/build.gradle.kts');
  final gradle = File('${pluginDir.path}/android/build.gradle');
  if (kts.existsSync()) {
    try {
      await kts.delete();
      stdout.writeln('Deleted $kts');
    } catch (_) {}
  }
  await gradle.writeAsString(_androidBuildGradle);
  stdout.writeln('Wrote Android build.gradle');
}

const _patchedPubspec = '''
name: real_page_flip
description: >
  A high-fidelity 3D-like page flip engine for Flutter. Features physics-based
  paper fold effects with realistic shadows, sound, and haptic feedback for
  ultra-smooth performance.
version: 2.2.9
repository: https://github.com/ChaPDCha/flutter_real_page_flip.git
homepage: https://github.com/ChaPDCha/flutter_real_page_flip
topics:
  - page-flip
  - animation
  - book
  - ebook
  - physics
issue_tracker: https://github.com/ChaPDCha/flutter_real_page_flip/issues
screenshots:
  - description: 'Four slow page turns in mobile single-page view using the high-quality rendering profile.'
    path: doc/screenshots/mobile_single_page_demo.webp
  - description: 'Four slow spread turns with distinct left and right pages on a 16:9 viewport.'
    path: doc/screenshots/mobile_double_spread_demo.webp

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  audioplayers: ^6.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  path: ^1.8.3
  http: ^1.2.1

false_secrets:
  - example/lib/shared/firebase/firebase_options.dart

flutter:
  plugin:
    platforms:
      android:
        package: com.chapdcha.real_page_flip
        pluginClass: RealPageFlipPlugin
      ios:
        pluginClass: RealPageFlipPlugin
      web:
        pluginClass: RealPageFlipWeb
        fileName: src/web/real_page_flip_web.dart

  assets:
    - assets/sounds/page_flip.mp3
    - assets/sounds/page_flip.opus
''';

const _androidBuildGradle = '''
group 'com.chapdcha.real_page_flip'
version '1.0-SNAPSHOT'

buildscript {
    ext.kotlin_version = '2.2.20'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.11.1'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:\$kotlin_version"
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'

android {
    namespace 'com.chapdcha.real_page_flip'
    compileSdk 36

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
        test.java.srcDirs += 'src/test/kotlin'
    }

    defaultConfig {
        minSdkVersion 24
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }
}

dependencies {
    testImplementation "org.jetbrains.kotlin:kotlin-test:\$kotlin_version"
    testImplementation "org.mockito:mockito-core:5.0.0"
}
''';
