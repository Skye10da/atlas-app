import 'package:shared_preferences/shared_preferences.dart';

import 'package:atlas_app/core/account/domain/entities/local_account_entity.dart';
import 'package:atlas_app/core/account/domain/repository_interfaces/local_account_repository_interface.dart';

final class SharedPrefsLocalAccountRepository
    implements LocalAccountRepositoryInterface {
  const SharedPrefsLocalAccountRepository();

  static const _key = 'local_account';

  @override
  Future<LocalAccountEntity> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return LocalAccountEntity(createdAt: DateTime.now());
    }
    return LocalAccountEntity.decode(raw);
  }

  @override
  Future<void> save(LocalAccountEntity account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, account.encode());
  }
}
