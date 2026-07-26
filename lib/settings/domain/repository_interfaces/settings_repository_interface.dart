import 'package:atlas_app/settings/domain/entities/reading_settings_entity.dart';

abstract interface class SettingsRepositoryInterface {
  Future<ReadingSettingsEntity> load();
  Future<void> save(ReadingSettingsEntity settings);
}
