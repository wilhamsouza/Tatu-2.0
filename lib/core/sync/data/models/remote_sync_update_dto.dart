import '../../domain/entities/inbox_update_type.dart';

class RemoteSyncUpdateDto {
  const RemoteSyncUpdateDto({
    required this.cursor,
    required this.updateType,
    required this.entityRemoteId,
    required this.payload,
    required this.updatedAt,
  });

  final String cursor;
  final InboxUpdateType updateType;
  final String entityRemoteId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;

  factory RemoteSyncUpdateDto.fromJson(Map<String, dynamic> json) {
    return RemoteSyncUpdateDto(
      cursor: json['cursor'] as String,
      updateType: InboxUpdateType.fromWireValue(json['updateType'] as String),
      entityRemoteId: json['entityRemoteId'] as String,
      payload: (json['payload'] as Map).cast<String, dynamic>(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
