import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';

/// Persistence for the single on-device account.
abstract interface class LocalAccountRepositoryInterface {
  Future<LocalAccountEntity> load();

  Future<void> save(LocalAccountEntity account);
}
