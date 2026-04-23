import '../../../../networking/api_client.dart';
import '../../models/remote_auth_session_dto.dart';

class AuthRemoteDatasource {
  const AuthRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<RemoteAuthSessionDto> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/auth/login',
      body: <String, Object?>{
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    return RemoteAuthSessionDto.fromJson(
      (response as Map).cast<String, dynamic>(),
    );
  }

  Future<RemoteAuthSessionDto> refresh({required String refreshToken}) async {
    final response = await _apiClient.postJson(
      path: '/api/auth/refresh',
      body: <String, Object?>{'refreshToken': refreshToken},
    );

    return RemoteAuthSessionDto.fromJson(
      (response as Map).cast<String, dynamic>(),
    );
  }

  Future<void> logout({required String refreshToken}) async {
    await _apiClient.postJson(
      path: '/api/auth/logout',
      body: <String, Object?>{'refreshToken': refreshToken},
    );
  }

  Future<void> registerDevice({
    required String accessToken,
    required String deviceId,
    required String platform,
    String? appVersion,
  }) async {
    await _apiClient.postJson(
      path: '/api/devices/register',
      bearerToken: accessToken,
      body: <String, Object?>{
        'deviceId': deviceId,
        'platform': platform,
        'appVersion': appVersion,
      },
    );
  }
}
