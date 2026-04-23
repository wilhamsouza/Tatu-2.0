import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/providers/auth_providers.dart';
import '../../logging/app_logger.dart';
import '../app_database.dart';

final appLoggerProvider = Provider<AppLogger>((ref) {
  return const AppLogger();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(logger: ref.read(appLoggerProvider));
  ref.onDispose(database.close);
  return database;
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final database = ref.read(appDatabaseProvider);
  await database.initialize();
  await ref.read(sessionLocalDatasourceProvider).ensureDeviceRegistration();
});
