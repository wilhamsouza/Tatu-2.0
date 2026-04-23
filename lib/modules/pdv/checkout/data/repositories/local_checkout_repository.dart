import '../../../../../core/auth/domain/entities/user_session.dart';
import '../../application/dtos/checkout_request.dart';
import '../../application/dtos/checkout_result.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../datasources/local/checkout_local_datasource.dart';

class LocalCheckoutRepository implements CheckoutRepository {
  const LocalCheckoutRepository({
    required CheckoutLocalDatasource localDatasource,
  }) : _localDatasource = localDatasource;

  final CheckoutLocalDatasource _localDatasource;

  @override
  Future<CheckoutResult> completeCheckout({
    required CheckoutRequest request,
    required UserSession session,
  }) {
    return _localDatasource.completeCheckout(
      request: request,
      session: session,
    );
  }
}
