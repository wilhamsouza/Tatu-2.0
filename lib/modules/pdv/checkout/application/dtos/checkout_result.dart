import '../../domain/entities/local_payment.dart';
import '../../domain/entities/local_sale.dart';
import '../../domain/entities/local_sale_item.dart';
import '../../../cash_register/domain/entities/cash_movement_type.dart';
import '../../../payments/domain/entities/payment_term.dart';
import '../../../quick_customer/domain/entities/quick_customer.dart';
import '../../../receipts/domain/entities/receipt.dart';

class CheckoutResult {
  const CheckoutResult({
    required this.sale,
    required this.items,
    required this.payment,
    this.paymentTerm,
    this.quickCustomer,
    required this.receipt,
    required this.cashMovementType,
  });

  final LocalSale sale;
  final List<LocalSaleItem> items;
  final LocalPayment payment;
  final PaymentTerm? paymentTerm;
  final QuickCustomer? quickCustomer;
  final Receipt receipt;
  final CashMovementType cashMovementType;
}
