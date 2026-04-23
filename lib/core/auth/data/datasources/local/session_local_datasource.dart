import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../../device_identity/domain/entities/device_registration.dart';
import '../../../../permissions/domain/entities/app_role.dart';
import '../../../../sync/domain/entities/sync_record_status.dart';
import '../../../../sync/domain/entities/sync_status_snapshot.dart';
import '../../../../tenancy/domain/entities/company_context.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/auth_token_pair.dart';
import '../../../domain/entities/user_session.dart';
import '../../../../database/app_database.dart';

class SessionLocalDatasource {
  SessionLocalDatasource({
    required AppDatabase database,
    required FlutterSecureStorage secureStorage,
    Uuid? uuid,
  }) : _database = database,
       _secureStorage = secureStorage,
       _uuid = uuid ?? const Uuid();

  static const String _accessTokenKey = 'session.access_token';
  static const String _refreshTokenKey = 'session.refresh_token';
  static const String _deviceIdKey = 'device.id';
  static const String _deviceRegisteredAtKey = 'device.registered_at';

  final AppDatabase _database;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  Future<DeviceRegistration> ensureDeviceRegistration() async {
    final secureDeviceId = await _secureStorage.read(key: _deviceIdKey);
    final secureRegisteredAt = await _secureStorage.read(
      key: _deviceRegisteredAtKey,
    );
    if (secureDeviceId != null && secureDeviceId.trim().isNotEmpty) {
      final registeredAt = secureRegisteredAt == null
          ? DateTime.now().toUtc()
          : DateTime.parse(secureRegisteredAt);
      final registration = DeviceRegistration(
        deviceId: secureDeviceId,
        platform: Platform.operatingSystem,
        registeredAt: registeredAt,
      );
      await _mirrorDeviceRegistration(registration);
      return registration;
    }

    final existingDatabaseRow = await _database.loadDeviceInfoRow();
    if (existingDatabaseRow != null) {
      final registration = DeviceRegistration(
        deviceId: existingDatabaseRow['device_id']! as String,
        platform: existingDatabaseRow['platform']! as String,
        registeredAt: DateTime.parse(
          existingDatabaseRow['registered_at']! as String,
        ),
      );
      await _persistSecureDeviceRegistration(registration);
      return registration;
    }

    final now = DateTime.now().toUtc();
    final registration = DeviceRegistration(
      deviceId: _uuid.v4(),
      platform: Platform.operatingSystem,
      registeredAt: now,
    );

    await _persistSecureDeviceRegistration(registration);
    await _mirrorDeviceRegistration(registration);

    return registration;
  }

  Future<void> _persistSecureDeviceRegistration(
    DeviceRegistration registration,
  ) async {
    await _secureStorage.write(key: _deviceIdKey, value: registration.deviceId);
    await _secureStorage.write(
      key: _deviceRegisteredAtKey,
      value: registration.registeredAt.toIso8601String(),
    );
  }

  Future<void> _mirrorDeviceRegistration(
    DeviceRegistration registration,
  ) async {
    final now = DateTime.now().toUtc();
    await _database.saveDeviceInfoRow(<String, Object?>{
      'id': 1,
      'device_id': registration.deviceId,
      'platform': registration.platform,
      'registered_at': registration.registeredAt.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  Future<void> saveSession(UserSession session) async {
    await _secureStorage.write(
      key: _accessTokenKey,
      value: session.tokens.accessToken,
    );
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: session.tokens.refreshToken,
    );

    await _database.saveUserSessionRow(<String, Object?>{
      'id': 1,
      'user_id': session.user.userId,
      'user_name': session.user.name,
      'user_email': session.user.email,
      'company_id': session.companyContext.companyId,
      'company_name': session.companyContext.companyName,
      'roles_json': jsonEncode(
        session.user.roles.map((role) => role.wireValue).toList(),
      ),
      'access_token_expires_at': session.tokens.expiresAt.toIso8601String(),
      'created_at': session.signedInAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<UserSession?> restoreSession() async {
    final row = await _database.loadUserSessionRow();
    if (row == null) {
      return null;
    }

    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) {
      return null;
    }

    final device = await ensureDeviceRegistration();
    final rolesRaw = (jsonDecode(row['roles_json']! as String) as List<dynamic>)
        .cast<String>();
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

    return UserSession(
      user: AppUser(
        userId: row['user_id']! as String,
        name: row['user_name']! as String,
        email: row['user_email']! as String,
        roles: rolesRaw.map(AppRole.fromWireValue).toList(),
        companyId: row['company_id']! as String,
      ),
      tokens: AuthTokenPair(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.parse(row['access_token_expires_at']! as String),
      ),
      companyContext: CompanyContext(
        companyId: row['company_id']! as String,
        companyName: row['company_name']! as String,
      ),
      deviceRegistration: device,
      signedInAt: DateTime.parse(row['created_at']! as String),
      syncStatus: syncStatus,
    );
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _database.clearUserSession();
  }
}
