import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/application/providers/auth_providers.dart';
import '../../data/datasources/remote/crm_remote_datasource.dart';
import '../../data/repositories/backend_crm_repository.dart';
import '../../domain/repositories/crm_repository.dart';

final crmRemoteDatasourceProvider = Provider<CrmRemoteDatasource>((ref) {
  return CrmRemoteDatasource(apiClient: ref.read(apiClientProvider));
});

final crmRepositoryProvider = Provider<CrmRepository>((ref) {
  return BackendCrmRepository(
    remoteDatasource: ref.read(crmRemoteDatasourceProvider),
  );
});
