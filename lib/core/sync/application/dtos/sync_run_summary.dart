class SyncRunSummary {
  const SyncRunSummary({
    this.processedOperations = 0,
    this.syncedOperations = 0,
    this.failedOperations = 0,
    this.conflictOperations = 0,
    this.receivedUpdates = 0,
    this.appliedUpdates = 0,
    this.transportFailed = false,
    this.updatesFailed = false,
  });

  final int processedOperations;
  final int syncedOperations;
  final int failedOperations;
  final int conflictOperations;
  final int receivedUpdates;
  final int appliedUpdates;
  final bool transportFailed;
  final bool updatesFailed;

  bool get hasIssues => failedOperations > 0 || conflictOperations > 0;

  bool get hadActivity =>
      processedOperations > 0 ||
      syncedOperations > 0 ||
      receivedUpdates > 0 ||
      appliedUpdates > 0;
}
