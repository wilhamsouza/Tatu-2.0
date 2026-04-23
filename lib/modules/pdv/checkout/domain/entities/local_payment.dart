import '../../../payments/domain/entities/payment_method.dart';

class LocalPayment {
  const LocalPayment({
    required this.localId,
    required this.saleLocalId,
    required this.method,
    required this.amountInCents,
    required this.changeInCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String localId;
  final String saleLocalId;
  final PaymentMethod method;
  final int amountInCents;
  final int changeInCents;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
