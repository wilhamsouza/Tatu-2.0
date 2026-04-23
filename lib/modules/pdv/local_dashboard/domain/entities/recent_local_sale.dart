import '../../../payments/domain/entities/payment_method.dart';
import '../../../payments/domain/entities/payment_status.dart';

class RecentLocalSale {
  const RecentLocalSale({
    required this.saleLocalId,
    required this.createdAt,
    required this.totalInCents,
    required this.itemCount,
    required this.paymentMethod,
    required this.receiptPath,
    this.customerName,
    this.paymentStatus,
    this.outstandingAmountInCents,
  });

  final String saleLocalId;
  final DateTime createdAt;
  final int totalInCents;
  final int itemCount;
  final PaymentMethod paymentMethod;
  final String receiptPath;
  final String? customerName;
  final PaymentStatus? paymentStatus;
  final int? outstandingAmountInCents;
}
