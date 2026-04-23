import '../entities/crm_entities.dart';

abstract class CrmRepository {
  Future<List<CrmCustomer>> listCustomers({
    required String accessToken,
    String? query,
  });

  Future<CrmCustomer> createCustomer({
    required String accessToken,
    required String name,
    required String phone,
    String? email,
    String? address,
    String? notes,
  });

  Future<CrmCustomer> updateCustomer({
    required String accessToken,
    required String customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  });

  Future<CrmCustomerHistory> loadCustomerHistory({
    required String accessToken,
    required String customerId,
  });

  Future<CrmCustomerSummary> loadCustomerSummary({
    required String accessToken,
    required String customerId,
  });

  Future<String> exportSegmentCsv({required String accessToken, String? query});
}
