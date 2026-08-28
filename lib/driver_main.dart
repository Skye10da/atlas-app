import 'package:flutter_driver/driver_extension.dart';

import 'package:atlas_app/main.dart' as app;

/// Entry point for automated UI driving (flutter_driver / Dart MCP
/// `flutter_driver` tool). Identical to [app.main] except that the flutter
/// driver extension is installed first, so taps/scrolls/finders can be driven
/// externally. Launch with: flutter run --target lib/driver_main.dart
Future<void> main() async {
  enableFlutterDriverExtension();
  app.main();
}
