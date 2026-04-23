import 'sync_operation_type.dart';
import 'sync_record_status.dart';

class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.deviceId,
    required this.companyId,
    required this.type,
    required this.entityLocalId,
    required this.payload,
    required this.status,
    required this.retries,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String operationId;
  final String deviceId;
  final String companyId;
  final SyncOperationType type;
  final String entityLocalId;
  final Map<String, dynamic> payload;
  final SyncRecordStatus status;
  final int retries;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
}
