import '../../../../auth/domain/entities/user_session.dart';
import '../../../../networking/api_client.dart';
import '../../models/remote_sync_operation_result_dto.dart';
import '../../models/remote_sync_updates_response_dto.dart';
import '../../../domain/entities/sync_operation.dart';

class SyncRemoteDatasource {
  const SyncRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<RemoteSyncOperationResultDto>> sendOutbox({
    required UserSession session,
    required List<SyncOperation> operations,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/sync/outbox',
      bearerToken: session.tokens.accessToken,
      body: <String, Object?>{
        'operations': operations.map((operation) {
          return <String, Object?>{
            'operationId': operation.operationId,
            'type': operation.type.wireValue,
            'entityLocalId': operation.entityLocalId,
            'payload': operation.payload,
          };
        }).toList(),
      },
    );

    final body = (response as Map).cast<String, dynamic>();
    final rawResults = (body['results'] as List<dynamic>? ?? const <dynamic>[]);
    return rawResults
        .map(
          (item) => RemoteSyncOperationResultDto.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  Future<RemoteSyncUpdatesResponseDto> fetchUpdates({
    required UserSession session,
    String? cursor,
    int limit = 50,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/sync/updates',
      bearerToken: session.tokens.accessToken,
      queryParameters: <String, String>{
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': '$limit',
      },
    );

    return RemoteSyncUpdatesResponseDto.fromJson(
      (response as Map).cast<String, dynamic>(),
    );
  }
}
