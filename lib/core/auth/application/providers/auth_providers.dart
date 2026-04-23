import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/providers/database_providers.dart';
import '../../../networking/api_client.dart';
import '../../data/datasources/local/session_local_datasource.dart';
import '../../data/datasources/remote/auth_remote_datasource.dart';
import '../../data/repositories/backend_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final sessionLocalDatasourceProvider = Provider<SessionLocalDatasource>((ref) {
  return SessionLocalDatasource(
    database: ref.read(appDatabaseProvider),
    secureStorage: ref.read(secureStorageProvider),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
});

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(apiClient: ref.read(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return BackendAuthRepository(
    localDatasource: ref.read(sessionLocalDatasourceProvider),
    remoteDatasource: ref.read(authRemoteDatasourceProvider),
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
});
