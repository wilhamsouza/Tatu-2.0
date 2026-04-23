import '../entities/quick_customer.dart';

abstract class QuickCustomerRepository {
  Future<List<QuickCustomer>> search(String query);
}
