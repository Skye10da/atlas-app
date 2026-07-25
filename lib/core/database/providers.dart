import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:atlas_app/core/database/database.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(DatabaseRef ref) => AppDatabase();
