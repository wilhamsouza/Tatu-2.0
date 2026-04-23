import '../../application/dtos/checkout_request.dart';
import '../../application/dtos/checkout_result.dart';
import '../../../../../core/auth/domain/entities/user_session.dart';

abstract class CheckoutRepository {
  Future<CheckoutResult> completeCheckout({
    required CheckoutRequest request,
    required UserSession session,
  });
}
