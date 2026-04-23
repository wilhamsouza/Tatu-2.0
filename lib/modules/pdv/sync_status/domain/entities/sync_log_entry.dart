class SyncLogEntry {
  const SyncLogEntry({
    required this.id,
    required this.level,
    required this.message,
    this.context,
    required this.createdAt,
  });

  final int id;
  final String level;
  final String message;
  final Map<String, dynamic>? context;
  final DateTime createdAt;
}
