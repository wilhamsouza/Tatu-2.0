import '../../../../../core/sync/domain/entities/sync_record_status.dart';
import 'settlement_payment_method.dart';

class ReceivablePaymentLocal {
  const ReceivablePaymentLocal({
    required this.localId,
    required this.paymentTermLocalId,
    this.remoteId,
    required this.amountInCents,
    required this.paymentMethodUsedForSettlement,
    required this.paidAt,
    this.notes,
    required this.createdByUserId,
    required this.cashSessionLocalId,
    required this.createdAt,
    required this.syncStatus,
  });

  final String localId;
  final String paymentTermLocalId;
  final String? remoteId;
  final int amountInCents;
  final SettlementPaymentMethod paymentMethodUsedForSettlement;
  final DateTime paidAt;
  final String? notes;
  final String createdByUserId;
  final String cashSessionLocalId;
  final DateTime createdAt;
  final SyncRecordStatus syncStatus;
}
