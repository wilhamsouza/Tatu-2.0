import '../../../../../core/sync/domain/entities/sync_record_status.dart';
import 'cash_movement_type.dart';

class CashMovement {
  const CashMovement({
    required this.localId,
    this.remoteId,
    required this.cashSessionLocalId,
    required this.type,
    required this.amountInCents,
    this.notes,
    required this.syncStatus,
    required this.createdAt,
  });

  final String localId;
  final String? remoteId;
  final String cashSessionLocalId;
  final CashMovementType type;
  final int amountInCents;
  final String? notes;
  final SyncRecordStatus syncStatus;
  final DateTime createdAt;
}
