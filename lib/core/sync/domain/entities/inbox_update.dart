import 'inbox_update_type.dart';

class InboxUpdate {
  const InboxUpdate({
    required this.id,
    required this.cursor,
    required this.updateType,
    required this.entityRemoteId,
    required this.payload,
    required this.receivedAt,
    this.appliedAt,
  });

  final int id;
  final String cursor;
  final InboxUpdateType updateType;
  final String entityRemoteId;
  final Map<String, dynamic> payload;
  final DateTime receivedAt;
  final DateTime? appliedAt;
}
