import '../../domain/entities/crm_entities.dart';
import '../../domain/repositories/crm_repository.dart';
import '../datasources/remote/crm_remote_datasource.dart';

class BackendCrmRepository implements CrmRepository {
  const BackendCrmRepository({required CrmRemoteDatasource remoteDatasource})
    : _remoteDatasource = remoteDatasource;

  final CrmRemoteDatasource _remoteDatasource;

  @override
  Future<List<CrmCustomer>> listCustomers({
    required String accessToken,
    String? query,
  }) async {
    final response = await _remoteDatasource.listCustomers(
      accessToken: accessToken,
      query: query,
    );
    return response.map(CrmCustomer.fromJson).toList();
  }

  @override
  Future<CrmCustomer> createCustomer({
    required String accessToken,
    required String name,
    required String phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final response = await _remoteDatasource.createCustomer(
      accessToken: accessToken,
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
    return CrmCustomer.fromJson(response);
  }

  @override
  Future<CrmCustomer> updateCustomer({
    required String accessToken,
    required String customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final response = await _remoteDatasource.updateCustomer(
      accessToken: accessToken,
      customerId: customerId,
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
    return CrmCustomer.fromJson(response);
  }

  @override
  Future<CrmCustomerHistory> loadCustomerHistory({
    required String accessToken,
    required String customerId,
  }) async {
    final response = await _remoteDatasource.fetchCustomerHistory(
      accessToken: accessToken,
      customerId: customerId,
    );
    return CrmCustomerHistory.fromJson(response);
  }

  @override
  Future<CrmCustomerSummary> loadCustomerSummary({
    required String accessToken,
    required String customerId,
  }) async {
    final response = await _remoteDatasource.fetchCustomerSummary(
      accessToken: accessToken,
      customerId: customerId,
    );
    return CrmCustomerSummary.fromJson(response);
  }

  @override
  Future<String> exportSegmentCsv({
    required String accessToken,
    String? query,
  }) {
    return _remoteDatasource.exportSegmentCsv(
      accessToken: accessToken,
      query: query,
    );
  }
}
