import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart';
import '../../../sync/domain/entities/sync_record_status.dart';
import '../../../sync/domain/entities/sync_status_snapshot.dart';
import '../../../tenancy/domain/entities/company_context.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_token_pair.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/session_local_datasource.dart';
import '../../../permissions/domain/entities/app_role.dart';

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({
    required SessionLocalDatasource localDatasource,
    required AppDatabase database,
    Uuid? uuid,
  }) : _localDatasource = localDatasource,
       _database = database,
       _uuid = uuid ?? const Uuid();

  final SessionLocalDatasource _localDatasource;
  final AppDatabase _database;
  final Uuid _uuid;

  static const String demoPassword = 'tatuzin123';

  static final Map<String, _DemoProfile> _profiles = <String, _DemoProfile>{
    'admin@tatuzin.app': _DemoProfile(
      userId: 'user_admin',
      name: 'Tatuzin Admin',
      companyId: 'company_tatuzin',
      companyName: 'Tatuzin Moda',
      roles: <AppRole>[AppRole.admin],
    ),
    'manager@tatuzin.app': _DemoProfile(
      userId: 'user_manager',
      name: 'Gerente Tatuzin',
      companyId: 'company_tatuzin',
      companyName: 'Tatuzin Moda',
      roles: <AppRole>[AppRole.manager],
    ),
    'seller@tatuzin.app': _DemoProfile(
      userId: 'user_seller',
      name: 'Vendedor Tatuzin',
      companyId: 'company_tatuzin',
      companyName: 'Tatuzin Moda',
      roles: <AppRole>[AppRole.seller],
    ),
    'cashier@tatuzin.app': _DemoProfile(
      userId: 'user_cashier',
      name: 'Operador de Caixa',
      companyId: 'company_tatuzin',
      companyName: 'Tatuzin Moda',
      roles: <AppRole>[AppRole.cashier],
    ),
    'crm@tatuzin.app': _DemoProfile(
      userId: 'user_crm',
      name: 'CRM Tatuzin',
      companyId: 'company_tatuzin',
      companyName: 'Tatuzin Moda',
      roles: <AppRole>[AppRole.crmUser],
    ),
  };

  @override
  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final profile = _profiles[normalizedEmail];
    if (profile == null || password != demoPassword) {
      throw const AuthException(
        'Credenciais inválidas. Use um dos usuários demo com a senha padrão.',
      );
    }

    final now = DateTime.now().toUtc();
    final device = await _localDatasource.ensureDeviceRegistration();
    final tokens = AuthTokenPair(
      accessToken: _uuid.v4(),
      refreshToken: _uuid.v4(),
      expiresAt: now.add(const Duration(hours: 8)),
    );

    final syncStatus = SyncStatusSnapshot(
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

    final session = UserSession(
      user: AppUser(
        userId: profile.userId,
        name: profile.name,
        email: normalizedEmail,
        roles: profile.roles,
        companyId: profile.companyId,
      ),
      tokens: tokens,
      companyContext: CompanyContext(
        companyId: profile.companyId,
        companyName: profile.companyName,
      ),
      deviceRegistration: device,
      signedInAt: now,
      syncStatus: syncStatus,
    );

    await _localDatasource.saveSession(session);
    return session;
  }

  @override
  Future<void> logout() async {
    await _localDatasource.clearSession();
  }

  @override
  Future<UserSession> refresh(UserSession session) async {
    final refreshed = session.copyWith(
      tokens: AuthTokenPair(
        accessToken: _uuid.v4(),
        refreshToken: _uuid.v4(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
      ),
    );

    await _localDatasource.saveSession(refreshed);
    return refreshed;
  }

  @override
  Future<UserSession?> restore() {
    return _localDatasource.restoreSession();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _DemoProfile {
  const _DemoProfile({
    required this.userId,
    required this.name,
    required this.companyId,
    required this.companyName,
    required this.roles,
  });

  final String userId;
  final String name;
  final String companyId;
  final String companyName;
  final List<AppRole> roles;
}
