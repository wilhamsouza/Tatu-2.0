import '../../../database/app_database.dart';
import '../../../logging/app_logger.dart';
import '../../../permissions/domain/entities/app_role.dart';
import '../../../sync/domain/entities/sync_record_status.dart';
import '../../../sync/domain/entities/sync_status_snapshot.dart';
import '../../../tenancy/domain/entities/company_context.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_token_pair.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/session_local_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/remote_auth_session_dto.dart';

class BackendAuthRepository implements AuthRepository {
  const BackendAuthRepository({
    required SessionLocalDatasource localDatasource,
    required AuthRemoteDatasource remoteDatasource,
    required AppDatabase database,
    required AppLogger logger,
  }) : _localDatasource = localDatasource,
       _remoteDatasource = remoteDatasource,
       _database = database,
       _logger = logger;

  final SessionLocalDatasource _localDatasource;
  final AuthRemoteDatasource _remoteDatasource;
  final AppDatabase _database;
  final AppLogger _logger;

  @override
  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final remoteSession = await _remoteDatasource.login(
      email: email,
      password: password,
    );

    return _persistRemoteSession(remoteSession);
  }

  @override
  Future<void> logout() async {
    final currentSession = await _localDatasource.restoreSession();
    if (currentSession != null) {
      try {
        await _remoteDatasource.logout(
          refreshToken: currentSession.tokens.refreshToken,
        );
      } catch (error, stackTrace) {
        _logger.warning(
          'Falha ao notificar logout remoto. Limpando sessao local mesmo assim.',
        );
        _logger.error('Erro no logout remoto.', error, stackTrace);
      }
    }

    await _localDatasource.clearSession();
  }

  @override
  Future<UserSession> refresh(UserSession session) async {
    final remoteSession = await _remoteDatasource.refresh(
      refreshToken: session.tokens.refreshToken,
    );
    return _persistRemoteSession(remoteSession);
  }

  @override
  Future<UserSession?> restore() {
    return _localDatasource.restoreSession();
  }

  Future<UserSession> _persistRemoteSession(
    RemoteAuthSessionDto remoteSession,
  ) async {
    final device = await _localDatasource.ensureDeviceRegistration();
    final session = UserSession(
      user: AppUser(
        userId: remoteSession.userId,
        name: remoteSession.name,
        email: remoteSession.email,
        roles: remoteSession.roles.map(AppRole.fromWireValue).toList(),
        companyId: remoteSession.companyId,
      ),
      tokens: AuthTokenPair(
        accessToken: remoteSession.accessToken,
        refreshToken: remoteSession.refreshToken,
        expiresAt: remoteSession.accessTokenExpiresAt.toUtc(),
      ),
      companyContext: CompanyContext(
        companyId: remoteSession.companyId,
        companyName: remoteSession.companyName,
      ),
      deviceRegistration: device,
      signedInAt: DateTime.now().toUtc(),
      syncStatus: await _loadSyncStatus(),
    );

    await _localDatasource.saveSession(session);

    try {
      await _remoteDatasource.registerDevice(
        accessToken: session.tokens.accessToken,
        deviceId: session.deviceRegistration.deviceId,
        platform: session.deviceRegistration.platform,
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'Falha ao registrar o dispositivo no backend. O app seguira com a sessao local.',
      );
      _logger.error('Erro ao registrar dispositivo remoto.', error, stackTrace);
    }

    return session;
  }

  Future<SyncStatusSnapshot> _loadSyncStatus() async {
    return SyncStatusSnapshot(
      pendingOperations: await _database.countOutboxOperationsByStatuses(
        const <SyncRecordStatus>[
          SyncRecordStatus.pending,
          SyncRecordStatus.failed,
        ],
      ),
      failedOperations: await _database.countOutboxOperationsByStatuses(
        const <SyncRecordStatus>[
          SyncRecordStatus.failed,
          SyncRecordStatus.conflict,
        ],
      ),
      lastSuccessfulSyncAt: await _database.loadLastSuccessfulSyncAt(),
    );
  }
}
