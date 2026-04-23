import '../../domain/entities/quick_customer.dart';
import '../../domain/repositories/quick_customer_repository.dart';
import '../datasources/local/quick_customer_local_datasource.dart';

class LocalQuickCustomerRepository implements QuickCustomerRepository {
  const LocalQuickCustomerRepository({
    required QuickCustomerLocalDatasource localDatasource,
  }) : _localDatasource = localDatasource;

  final QuickCustomerLocalDatasource _localDatasource;

  @override
  Future<List<QuickCustomer>> search(String query) {
    return _localDatasource.search(query);
  }
}
