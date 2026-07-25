abstract final class AppConstants {
  static const String appName = 'Atlas';
  static const String appVersion = '1.0.0';

  static const String databaseName = 'atlas.db';
  static const int databaseVersion = 1;

  static const int searchDebounceMs = 300;
  static const int maxSearchResults = 50;
  static const int pageSize = 20;

  static const double minFontSize = 12;
  static const double maxFontSize = 36;
  static const double defaultFontSize = 18;

  static const double minLineHeight = 1.2;
  static const double maxLineHeight = 2.5;
  static const double defaultLineHeight = 1.6;

  static const Duration aiTimeout = Duration(seconds: 30);
  static const Duration syncInterval = Duration(minutes: 5);
  static const Duration cacheDuration = Duration(hours: 24);
}
