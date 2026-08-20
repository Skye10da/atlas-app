import 'package:logger/logger.dart' as pkg;

abstract final class AppLogger {
  static final _logger = pkg.Logger(
    printer: pkg.PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: false,
    ),
  );

  static Level _level = Level.debug;

  static void setLevel(Level level) {
    _level = level;
  }

  static void debug(String message) {
    if (_level.index <= Level.debug.index) _logger.d(message);
  }

  static void info(String message) {
    if (_level.index <= Level.info.index) _logger.i(message);
  }

  static void warning(String message) {
    if (_level.index <= Level.warning.index) _logger.w(message);
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    _logger.e(message, error: error, stackTrace: stack);
  }
}

enum Level { debug, info, warning, error, silent }
