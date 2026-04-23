import '../../../../../core/sync/domain/entities/sync_record_status.dart';

class QuickCustomer {
  const QuickCustomer({
    required this.localId,
    this.remoteId,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  final String localId;
  final String? remoteId;
  final String name;
  final String phone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncRecordStatus syncStatus;
}
