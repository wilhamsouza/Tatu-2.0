import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/application/providers/auth_providers.dart';
import '../../data/datasources/remote/erp_remote_datasource.dart';
import '../../data/repositories/backend_erp_repository.dart';
import '../../domain/repositories/erp_repository.dart';

final erpRemoteDatasourceProvider = Provider<ErpRemoteDatasource>((ref) {
  return ErpRemoteDatasource(apiClient: ref.read(apiClientProvider));
});

final erpRepositoryProvider = Provider<ErpRepository>((ref) {
  return BackendErpRepository(
    remoteDatasource: ref.read(erpRemoteDatasourceProvider),
  );
});
