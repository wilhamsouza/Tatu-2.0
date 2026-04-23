import 'dart:convert';

import '../../../../../../core/database/app_database.dart';
import '../../../../../../core/database/local_database_executor.dart';
import '../../../../../../core/networking/api_client.dart';
import '../../../../../../core/sync/domain/entities/sync_operation_type.dart';
import '../../../../../../core/sync/domain/entities/sync_conflict.dart';
import '../../../../../../core/sync/domain/entities/sync_record_status.dart';
import '../../../../../../core/sync/domain/entities/sync_status_snapshot.dart';
import '../../../application/dtos/sync_status_details.dart';
import '../../../domain/entities/sync_log_entry.dart';
import '../../../domain/entities/sync_queue_operation.dart';

class SyncStatusLocalDatasource {
  const SyncStatusLocalDatasource({
    required AppDatabase database,
    required ApiClient apiClient,
  }) : _database = database,
       _apiClient = apiClient;

  final AppDatabase _database;
  final ApiClient _apiClient;

  Future<SyncStatusDetails> loadDetails() async {
    final db = await _database.database;
    final customApiBaseUrl = await _database.loadAppSetting(
      ApiClient.apiBaseUrlSettingKey,
    );
    final effectiveApiBaseUrl = await _apiClient.resolveBaseUrl();
    final cursor = await _loadCursor(db);
    final recentConflicts = await _loadRecentConflicts(db);
    final recentLogs = await _loadRecentLogs(db);
    final recentOperations = await _loadRecentOperations(db);

    final snapshot = SyncStatusSnapshot(
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

    return SyncStatusDetails(
      snapshot: snapshot,
      effectiveApiBaseUrl: effectiveApiBaseUrl,
      customApiBaseUrl: customApiBaseUrl,
      cursor: cursor,
      recentConflicts: recentConflicts,
      recentLogs: recentLogs,
      recentOperations: recentOperations,
    );
  }

  Future<void> saveApiBaseUrl(String value) {
    return _database.saveAppSetting(
      key: ApiClient.apiBaseUrlSettingKey,
      value: value.trim(),
    );
  }

  Future<void> resetApiBaseUrl() {
    return _database.deleteAppSetting(ApiClient.apiBaseUrlSettingKey);
  }

  Future<int> retryIssueOperations() async {
    final db = await _database.database;
    final rows = await db.query(
      'sync_outbox',
      columns: <String>['operation_id'],
      where: 'status IN (?, ?)',
      whereArgs: <Object>[
        SyncRecordStatus.failed.wireValue,
        SyncRecordStatus.conflict.wireValue,
      ],
    );

    if (rows.isEmpty) {
      return 0;
    }

    await db.transaction((txn) async {
      for (final row in rows) {
        await _retryOperationInTransaction(txn, row['operation_id']! as String);
      }
    });

    await _database.appendSyncLog(
      level: 'info',
      message: 'Issue operations moved back to pending.',
      context: <String, Object?>{'count': rows.length},
    );

    return rows.length;
  }

  Future<void> retryOperation(String operationId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await _retryOperationInTransaction(txn, operationId);
    });

    await _database.appendSyncLog(
      level: 'info',
      message: 'Single operation moved back to pending.',
      context: <String, Object?>{'operationId': operationId},
    );
  }

  Future<String?> _loadCursor(LocalDatabaseExecutor db) async {
    final rows = await db.query(
      'sync_cursor',
      where: 'id = ?',
      whereArgs: <Object>[1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['cursor_value'] as String?;
  }

  Future<List<SyncConflict>> _loadRecentConflicts(
    LocalDatabaseExecutor db,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT conflicts.id,
             conflicts.operation_id,
             conflicts.conflict_type,
             conflicts.details_json,
             conflicts.created_at
      FROM sync_conflicts AS conflicts
      INNER JOIN sync_outbox AS outbox
        ON outbox.operation_id = conflicts.operation_id
      WHERE outbox.status = ?
      ORDER BY conflicts.created_at DESC
      LIMIT 5
      ''',
      <Object>[SyncRecordStatus.conflict.wireValue],
    );

    return rows.map((row) {
      return SyncConflict(
        id: row['id']! as int,
        operationId: row['operation_id']! as String,
        conflictType: row['conflict_type']! as String,
        details: (jsonDecode(row['details_json']! as String) as Map)
            .cast<String, dynamic>(),
        createdAt: DateTime.parse(row['created_at']! as String),
      );
    }).toList();
  }

  Future<List<SyncLogEntry>> _loadRecentLogs(LocalDatabaseExecutor db) async {
    final rows = await db.query('sync_logs', orderBy: 'id DESC', limit: 8);

    return rows.map((row) {
      return SyncLogEntry(
        id: row['id']! as int,
        level: row['level']! as String,
        message: row['message']! as String,
        context: row['context_json'] == null
            ? null
            : (jsonDecode(row['context_json']! as String) as Map)
                  .cast<String, dynamic>(),
        createdAt: DateTime.parse(row['created_at']! as String),
      );
    }).toList();
  }

  Future<List<SyncQueueOperation>> _loadRecentOperations(
    LocalDatabaseExecutor db,
  ) async {
    final rows = await db.query(
      'sync_outbox',
      orderBy: 'updated_at DESC',
      limit: 10,
    );

    return rows.map((row) {
      return SyncQueueOperation(
        operationId: row['operation_id']! as String,
        type: SyncOperationType.fromWireValue(row['type']! as String),
        entityLocalId: row['entity_local_id']! as String,
        status: SyncRecordStatus.fromWireValue(row['status']! as String),
        retries: row['retries']! as int,
        lastError: row['last_error'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );
    }).toList();
  }

  Future<void> _retryOperationInTransaction(
    LocalDatabaseExecutor txn,
    String operationId,
  ) async {
    final rows = await txn.query(
      'sync_outbox',
      where: 'operation_id = ?',
      whereArgs: <Object>[operationId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }

    final row = rows.first;
    final operation = SyncQueueOperation(
      operationId: row['operation_id']! as String,
      type: SyncOperationType.fromWireValue(row['type']! as String),
      entityLocalId: row['entity_local_id']! as String,
      status: SyncRecordStatus.fromWireValue(row['status']! as String),
      retries: row['retries']! as int,
      lastError: row['last_error'] as String?,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );

    final now = DateTime.now().toUtc().toIso8601String();
    await txn.update(
      'sync_outbox',
      <String, Object?>{
        'status': SyncRecordStatus.pending.wireValue,
        'retries': 0,
        'last_error': null,
        'updated_at': now,
      },
      where: 'operation_id = ?',
      whereArgs: <Object>[operationId],
    );

    await _setEntityPendingStatus(
      txn: txn,
      operation: operation,
      updatedAt: now,
    );
  }

  Future<void> _setEntityPendingStatus({
    required LocalDatabaseExecutor txn,
    required SyncQueueOperation operation,
    required String updatedAt,
  }) async {
    switch (operation.type) {
      case SyncOperationType.quickCustomer:
        await txn.update(
          'quick_customers',
          <String, Object?>{
            'sync_status': SyncRecordStatus.pending.wireValue,
            'updated_at': updatedAt,
          },
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
      case SyncOperationType.cashMovement:
        await txn.update(
          'cash_movements',
          <String, Object?>{'sync_status': SyncRecordStatus.pending.wireValue},
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
      case SyncOperationType.receivableNote:
        await txn.update(
          'payment_terms',
          <String, Object?>{
            'sync_status': SyncRecordStatus.pending.wireValue,
            'updated_at': updatedAt,
          },
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
      case SyncOperationType.receivableSettlement:
        await txn.update(
          'receivable_payments',
          <String, Object?>{'sync_status': SyncRecordStatus.pending.wireValue},
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
      case SyncOperationType.sale:
        await txn.update(
          'sales',
          <String, Object?>{'updated_at': updatedAt},
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
    }
  }
}
