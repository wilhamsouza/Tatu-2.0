class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.pendingOperations,
    required this.failedOperations,
    this.lastSuccessfulSyncAt,
  });

  final int pendingOperations;
  final int failedOperations;
  final DateTime? lastSuccessfulSyncAt;

  bool get hasIssues => failedOperations > 0;
}
