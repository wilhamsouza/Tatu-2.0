import '../../../../../core/sync/domain/entities/sync_conflict.dart';
import '../../../../../core/sync/domain/entities/sync_status_snapshot.dart';
import '../../domain/entities/sync_log_entry.dart';
import '../../domain/entities/sync_queue_operation.dart';

class SyncStatusDetails {
  const SyncStatusDetails({
    required this.snapshot,
    required this.effectiveApiBaseUrl,
    this.customApiBaseUrl,
    this.cursor,
    required this.recentConflicts,
    required this.recentLogs,
    required this.recentOperations,
  });

  final SyncStatusSnapshot snapshot;
  final String effectiveApiBaseUrl;
  final String? customApiBaseUrl;
  final String? cursor;
  final List<SyncConflict> recentConflicts;
  final List<SyncLogEntry> recentLogs;
  final List<SyncQueueOperation> recentOperations;
}
