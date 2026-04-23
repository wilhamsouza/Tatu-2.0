import '../../../../../core/auth/domain/entities/user_session.dart';
import '../../application/dtos/checkout_request.dart';
import '../../application/dtos/checkout_result.dart';
import '../../domain/repositories/checkout_repository.dart';

class CompleteCheckoutUseCase {
  const CompleteCheckoutUseCase(this._repository);

  final CheckoutRepository _repository;

  Future<CheckoutResult> call({
    required CheckoutRequest request,
    required UserSession session,
  }) {
    return _repository.completeCheckout(request: request, session: session);
  }
}
