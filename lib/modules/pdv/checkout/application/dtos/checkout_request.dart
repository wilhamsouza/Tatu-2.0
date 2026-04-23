import '../../../cart/domain/entities/cart.dart';
import '../../../payments/domain/entities/payment_method.dart';

class CheckoutRequest {
  const CheckoutRequest({
    required this.cart,
    required this.paymentMethod,
    required this.amountReceivedInCents,
    required this.pixConfirmedManually,
    this.noteDueDate,
    this.noteDescription,
    this.customerName,
    this.customerPhone,
  });

  final Cart cart;
  final PaymentMethod paymentMethod;
  final int amountReceivedInCents;
  final bool pixConfirmedManually;
  final DateTime? noteDueDate;
  final String? noteDescription;
  final String? customerName;
  final String? customerPhone;
}
