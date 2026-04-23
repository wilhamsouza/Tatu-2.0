class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.operationId,
    required this.conflictType,
    required this.details,
    required this.createdAt,
  });

  final int id;
  final String operationId;
  final String conflictType;
  final Map<String, dynamic> details;
  final DateTime createdAt;
}
