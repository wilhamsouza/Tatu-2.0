import '../../../../../core/sync/domain/entities/sync_operation_type.dart';
import '../../../../../core/sync/domain/entities/sync_record_status.dart';

class SyncQueueOperation {
  const SyncQueueOperation({
    required this.operationId,
    required this.type,
    required this.entityLocalId,
    required this.status,
    required this.retries,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String operationId;
  final SyncOperationType type;
  final String entityLocalId;
  final SyncRecordStatus status;
  final int retries;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get canRetry =>
      status == SyncRecordStatus.failed || status == SyncRecordStatus.conflict;
}
