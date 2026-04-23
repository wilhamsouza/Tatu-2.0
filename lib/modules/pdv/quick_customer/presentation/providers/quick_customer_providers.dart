import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers/database_providers.dart';
import '../../data/datasources/local/quick_customer_local_datasource.dart';
import '../../data/repositories/local_quick_customer_repository.dart';
import '../../domain/entities/quick_customer.dart';
import '../../domain/repositories/quick_customer_repository.dart';

final quickCustomerLocalDatasourceProvider =
    Provider<QuickCustomerLocalDatasource>((ref) {
      return QuickCustomerLocalDatasource(
        database: ref.read(appDatabaseProvider),
      );
    });

final quickCustomerRepositoryProvider = Provider<QuickCustomerRepository>((
  ref,
) {
  return LocalQuickCustomerRepository(
    localDatasource: ref.read(quickCustomerLocalDatasourceProvider),
  );
});

final quickCustomerSearchProvider =
    FutureProvider.family<List<QuickCustomer>, String>((ref, query) {
      return ref.read(quickCustomerRepositoryProvider).search(query);
    });
