import 'remote_sync_update_dto.dart';

class RemoteSyncUpdatesResponseDto {
  const RemoteSyncUpdatesResponseDto({required this.updates, this.nextCursor});

  final List<RemoteSyncUpdateDto> updates;
  final String? nextCursor;

  factory RemoteSyncUpdatesResponseDto.fromJson(Map<String, dynamic> json) {
    final rawUpdates = (json['updates'] as List<dynamic>? ?? const <dynamic>[]);
    return RemoteSyncUpdatesResponseDto(
      updates: rawUpdates
          .map(
            (item) => RemoteSyncUpdateDto.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}
