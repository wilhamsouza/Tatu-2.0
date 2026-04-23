import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';
import '../sync/domain/entities/sync_record_status.dart';
import 'local_database_executor.dart';
import 'schema/app_database_schema.dart';

class AppDatabase {
  AppDatabase({
    required AppLogger logger,
    QueryExecutor? queryExecutorOverride,
    String? databasePathOverride,
  }) : _logger = logger,
       _queryExecutorOverride = queryExecutorOverride,
       _databasePathOverride = databasePathOverride;

  final AppLogger _logger;
  final QueryExecutor? _queryExecutorOverride;
  final String? _databasePathOverride;

  LocalDatabaseExecutor? _database;

  Future<LocalDatabaseExecutor> get database async {
    if (_database != null) {
      return _database!;
    }
    return initialize();
  }

  Future<LocalDatabaseExecutor> initialize() async {
    if (_database != null) {
      return _database!;
    }

    final path = _databasePathOverride ?? await _resolveDatabasePath();
    final executor = _queryExecutorOverride ?? await _openNativeExecutor(path);
    final driftDatabase = LocalSqlDatabase(executor);
    final database = LocalDatabaseExecutor(driftDatabase, path: path);

    for (final statement in AppDatabaseSchema.initialStatements) {
      await database.execute(statement);
    }

    _database = database;
    return database;
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) {
      await db.close();
    }
  }

  Future<Map<String, Object?>?> loadUserSessionRow() async {
    final db = await database;
    final rows = await db.query(
      'user_session',
      where: 'id = ?',
      whereArgs: <Object?>[1],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveUserSessionRow(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      'user_session',
      row,
      conflictAlgorithm: LocalConflictAlgorithm.replace,
    );
  }

  Future<void> clearUserSession() async {
    final db = await database;
    await db.delete('user_session', where: 'id = ?', whereArgs: <Object?>[1]);
  }

  Future<Map<String, Object?>?> loadDeviceInfoRow() async {
    final db = await database;
    final rows = await db.query(
      'device_info',
      where: 'id = ?',
      whereArgs: <Object?>[1],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveDeviceInfoRow(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      'device_info',
      row,
      conflictAlgorithm: LocalConflictAlgorithm.replace,
    );
  }

  Future<String?> loadAppSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> saveAppSetting({
    required String key,
    required String value,
  }) async {
    final db = await database;
    await db.insert('app_settings', <String, Object?>{
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: LocalConflictAlgorithm.replace);
  }

  Future<void> deleteAppSetting(String key) async {
    final db = await database;
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: <Object?>[key],
    );
  }

  Future<int> countOutboxOperationsByStatuses(
    List<SyncRecordStatus> statuses,
  ) async {
    final db = await database;
    final placeholders = List.filled(statuses.length, '?').join(', ');
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM sync_outbox
      WHERE status IN ($placeholders)
      ''', statuses.map((status) => status.wireValue).toList());

    return (result.first['total'] as int?) ?? 0;
  }

  Future<DateTime?> loadLastSuccessfulSyncAt() async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT MAX(updated_at) AS last_synced_at
      FROM sync_outbox
      WHERE status = ?
      ''',
      <Object?>[SyncRecordStatus.synced.wireValue],
    );
    final raw = result.first['last_synced_at'] as String?;
    return raw == null ? null : DateTime.parse(raw);
  }

  Future<void> appendSyncLog({
    required String level,
    required String message,
    Map<String, Object?>? context,
  }) async {
    final db = await database;
    await appendSyncLogWithExecutor(
      executor: db,
      level: level,
      message: message,
      context: context,
    );
  }

  Future<void> appendSyncLogWithExecutor({
    required LocalDatabaseExecutor executor,
    required String level,
    required String message,
    Map<String, Object?>? context,
  }) async {
    await executor.insert('sync_logs', <String, Object?>{
      'level': level,
      'message': message,
      'context_json': context == null ? null : jsonEncode(context),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<QueryExecutor> _openNativeExecutor(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    _logger.info('Opening local Drift database at $path');
    return NativeDatabase(file);
  }

  Future<String> _resolveDatabasePath() async {
    if (kIsWeb) {
      throw UnsupportedError('Tatuzin local database requires native SQLite.');
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return p.join(Directory.current.path, 'tatuzin_local.db');
    }
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'tatuzin_local.db');
  }
}
