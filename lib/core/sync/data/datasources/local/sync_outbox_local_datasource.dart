import 'dart:convert';
import 'dart:math';

import '../../../../database/app_database.dart';
import '../../../../database/local_database_executor.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_type.dart';
import '../../../domain/entities/sync_record_status.dart';
import '../../../domain/entities/sync_status_snapshot.dart';

class SyncOutboxLocalDatasource {
  const SyncOutboxLocalDatasource({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<List<SyncOperation>> loadOperationsForProcessing({
    int limit = 20,
  }) async {
    final db = await _database.database;
    final pendingRows = await db.query(
      'sync_outbox',
      where: 'status = ?',
      whereArgs: <Object>[SyncRecordStatus.pending.wireValue],
      orderBy: 'created_at ASC',
    );

    final failedRows = await db.query(
      'sync_outbox',
      where: 'status = ?',
      whereArgs: <Object>[SyncRecordStatus.failed.wireValue],
      orderBy: 'updated_at ASC',
    );

    final operations = <SyncOperation>[
      ...pendingRows.map(_mapOperation),
      ...failedRows.map(_mapOperation).where(_isReadyForRetry),
    ]..sort(_compareOperations);

    return _selectProcessableOperations(
      executor: db,
      operations: operations,
      limit: limit,
    );
  }

  Future<void> markOperationsSending(List<String> operationIds) async {
    if (operationIds.isEmpty) {
      return;
    }

    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final operationId in operationIds) {
        final row = await _loadOperationRow(txn, operationId);
        if (row == null) {
          continue;
        }

        await txn.update(
          'sync_outbox',
          <String, Object?>{
            'status': SyncRecordStatus.sending.wireValue,
            'updated_at': now,
          },
          where: 'operation_id = ?',
          whereArgs: <Object>[operationId],
        );

        final operation = _mapOperation(row);
        await _updateEntitySyncStatus(
          executor: txn,
          operation: operation,
          status: SyncRecordStatus.sending,
          updatedAt: now,
        );
        await _database.appendSyncLogWithExecutor(
          executor: txn,
          level: 'info',
          message: 'Outbox operation is sending.',
          context: <String, Object?>{
            'operationId': operation.operationId,
            'type': operation.type.wireValue,
            'entityLocalId': operation.entityLocalId,
          },
        );
      }
    });
  }

  Future<void> markOperationSynced({
    required SyncOperation operation,
    Map<String, dynamic>? remoteData,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final remoteId = _extractRemoteId(operation.type, remoteData);

    await db.transaction((txn) async {
      await txn.update(
        'sync_outbox',
        <String, Object?>{
          'status': SyncRecordStatus.synced.wireValue,
          'last_error': null,
          'updated_at': now,
        },
        where: 'operation_id = ?',
        whereArgs: <Object>[operation.operationId],
      );

      switch (operation.type) {
        case SyncOperationType.sale:
          await txn.update(
            'sales',
            <String, Object?>{
              'remote_id': remoteId,
              'synced_at': now,
              'updated_at': now,
            },
            where: 'local_id = ?',
            whereArgs: <Object>[operation.entityLocalId],
          );
          break;
        case SyncOperationType.quickCustomer:
        case SyncOperationType.cashMovement:
        case SyncOperationType.receivableNote:
        case SyncOperationType.receivableSettlement:
          await _updateEntitySyncStatus(
            executor: txn,
            operation: operation,
            status: SyncRecordStatus.synced,
            updatedAt: now,
            remoteId: remoteId,
          );
          break;
      }

      await _database.appendSyncLogWithExecutor(
        executor: txn,
        level: 'info',
        message: 'Outbox operation synced successfully.',
        context: <String, Object?>{
          'operationId': operation.operationId,
          'type': operation.type.wireValue,
          'entityLocalId': operation.entityLocalId,
          'remoteId': remoteId,
        },
      );
    });
  }

  Future<void> markOperationFailed({
    required SyncOperation operation,
    required String errorMessage,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'sync_outbox',
        <String, Object?>{
          'status': SyncRecordStatus.failed.wireValue,
          'retries': operation.retries + 1,
          'last_error': errorMessage,
          'updated_at': now,
        },
        where: 'operation_id = ?',
        whereArgs: <Object>[operation.operationId],
      );

      await _updateEntitySyncStatus(
        executor: txn,
        operation: operation,
        status: SyncRecordStatus.failed,
        updatedAt: now,
      );

      await _database.appendSyncLogWithExecutor(
        executor: txn,
        level: 'warning',
        message: 'Outbox operation failed and will retry.',
        context: <String, Object?>{
          'operationId': operation.operationId,
          'type': operation.type.wireValue,
          'entityLocalId': operation.entityLocalId,
          'retries': operation.retries + 1,
          'error': errorMessage,
        },
      );
    });
  }

  Future<void> markOperationConflict({
    required SyncOperation operation,
    required String conflictType,
    required String errorMessage,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'sync_outbox',
        <String, Object?>{
          'status': SyncRecordStatus.conflict.wireValue,
          'last_error': errorMessage,
          'updated_at': now,
        },
        where: 'operation_id = ?',
        whereArgs: <Object>[operation.operationId],
      );

      await txn.insert('sync_conflicts', <String, Object?>{
        'operation_id': operation.operationId,
        'conflict_type': conflictType,
        'details_json': jsonEncode(<String, Object?>{
          'message': errorMessage,
          'operationType': operation.type.wireValue,
          'entityLocalId': operation.entityLocalId,
        }),
        'created_at': now,
      });

      await _updateEntitySyncStatus(
        executor: txn,
        operation: operation,
        status: SyncRecordStatus.conflict,
        updatedAt: now,
      );

      await _database.appendSyncLogWithExecutor(
        executor: txn,
        level: 'warning',
        message: 'Outbox operation moved to conflict.',
        context: <String, Object?>{
          'operationId': operation.operationId,
          'type': operation.type.wireValue,
          'entityLocalId': operation.entityLocalId,
          'conflictType': conflictType,
          'error': errorMessage,
        },
      );
    });
  }

  Future<SyncStatusSnapshot> loadStatusSnapshot() async {
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

  bool _isReadyForRetry(SyncOperation operation) {
    final delayInSeconds = min(pow(2, operation.retries).toInt() * 5, 300);
    final nextAttemptAt = operation.updatedAt.add(
      Duration(seconds: delayInSeconds),
    );
    return !nextAttemptAt.isAfter(DateTime.now().toUtc());
  }

  Future<List<SyncOperation>> _selectProcessableOperations({
    required LocalDatabaseExecutor executor,
    required List<SyncOperation> operations,
    required int limit,
  }) async {
    if (operations.isEmpty || limit <= 0) {
      return const <SyncOperation>[];
    }

    final remaining = List<SyncOperation>.from(operations);
    final selected = <SyncOperation>[];
    final resolvedDependencies = <_SyncDependencyKey>{};

    while (remaining.isNotEmpty && selected.length < limit) {
      var progressed = false;

      for (var index = 0; index < remaining.length; index += 1) {
        final operation = remaining[index];
        if (!await _hasResolvedDependencies(
          executor: executor,
          operation: operation,
          resolvedDependencies: resolvedDependencies,
        )) {
          continue;
        }

        selected.add(operation);
        resolvedDependencies.add(_dependencyKeyFor(operation));
        remaining.removeAt(index);
        progressed = true;
        break;
      }

      if (!progressed) {
        break;
      }
    }

    return selected;
  }

  Future<bool> _hasResolvedDependencies({
    required LocalDatabaseExecutor executor,
    required SyncOperation operation,
    required Set<_SyncDependencyKey> resolvedDependencies,
  }) async {
    for (final dependency in _dependenciesFor(operation)) {
      if (resolvedDependencies.contains(dependency)) {
        continue;
      }

      if (!await _isDependencyAlreadySynced(
        executor: executor,
        dependency: dependency,
      )) {
        return false;
      }
    }

    return true;
  }

  Iterable<_SyncDependencyKey> _dependenciesFor(SyncOperation operation) sync* {
    switch (operation.type) {
      case SyncOperationType.quickCustomer:
        break;
      case SyncOperationType.sale:
        final customerLocalId = _readOptionalString(
          operation.payload['customerLocalId'],
        );
        if (customerLocalId != null) {
          yield _SyncDependencyKey.quickCustomer(customerLocalId);
        }
        break;
      case SyncOperationType.cashMovement:
        final saleLocalId = _readOptionalString(
          operation.payload['saleLocalId'],
        );
        if (saleLocalId != null) {
          yield _SyncDependencyKey.sale(saleLocalId);
        }
        break;
      case SyncOperationType.receivableNote:
        final saleLocalId = _readOptionalString(
          operation.payload['saleLocalId'],
        );
        if (saleLocalId != null) {
          yield _SyncDependencyKey.sale(saleLocalId);
        }

        final customerLocalId = _readOptionalString(
          operation.payload['customerLocalId'],
        );
        if (customerLocalId != null) {
          yield _SyncDependencyKey.quickCustomer(customerLocalId);
        }
        break;
      case SyncOperationType.receivableSettlement:
        final paymentTermLocalId = _readOptionalString(
          operation.payload['paymentTermLocalId'],
        );
        if (paymentTermLocalId != null) {
          yield _SyncDependencyKey.receivableNote(paymentTermLocalId);
        }
        break;
    }
  }

  Future<bool> _isDependencyAlreadySynced({
    required LocalDatabaseExecutor executor,
    required _SyncDependencyKey dependency,
  }) async {
    switch (dependency.type) {
      case SyncOperationType.quickCustomer:
        final rows = await executor.query(
          'quick_customers',
          columns: <String>['remote_id', 'sync_status'],
          where: 'local_id = ?',
          whereArgs: <Object>[dependency.localId],
          limit: 1,
        );
        if (rows.isEmpty) {
          return false;
        }

        final row = rows.first;
        return row['remote_id'] != null ||
            row['sync_status'] == SyncRecordStatus.synced.wireValue;
      case SyncOperationType.sale:
        final rows = await executor.query(
          'sales',
          columns: <String>['remote_id', 'synced_at'],
          where: 'local_id = ?',
          whereArgs: <Object>[dependency.localId],
          limit: 1,
        );
        if (rows.isEmpty) {
          return false;
        }

        final row = rows.first;
        return row['remote_id'] != null || row['synced_at'] != null;
      case SyncOperationType.receivableNote:
        final rows = await executor.query(
          'payment_terms',
          columns: <String>['remote_id', 'sync_status'],
          where: 'local_id = ?',
          whereArgs: <Object>[dependency.localId],
          limit: 1,
        );
        if (rows.isEmpty) {
          return false;
        }

        final row = rows.first;
        return row['remote_id'] != null ||
            row['sync_status'] == SyncRecordStatus.synced.wireValue;
      case SyncOperationType.cashMovement:
      case SyncOperationType.receivableSettlement:
        return false;
    }
  }

  _SyncDependencyKey _dependencyKeyFor(SyncOperation operation) {
    switch (operation.type) {
      case SyncOperationType.quickCustomer:
        return _SyncDependencyKey.quickCustomer(operation.entityLocalId);
      case SyncOperationType.sale:
        return _SyncDependencyKey.sale(operation.entityLocalId);
      case SyncOperationType.receivableNote:
        return _SyncDependencyKey.receivableNote(operation.entityLocalId);
      case SyncOperationType.cashMovement:
      case SyncOperationType.receivableSettlement:
        return _SyncDependencyKey.operation(
          operation.type,
          operation.entityLocalId,
        );
    }
  }

  int _compareOperations(SyncOperation left, SyncOperation right) {
    final byPriority = _priorityFor(left).compareTo(_priorityFor(right));
    if (byPriority != 0) {
      return byPriority;
    }

    final byTimestamp = _sortTimestampFor(
      left,
    ).compareTo(_sortTimestampFor(right));
    if (byTimestamp != 0) {
      return byTimestamp;
    }

    return left.operationId.compareTo(right.operationId);
  }

  int _priorityFor(SyncOperation operation) {
    switch (operation.type) {
      case SyncOperationType.quickCustomer:
        return 0;
      case SyncOperationType.sale:
        return 1;
      case SyncOperationType.cashMovement:
        return 2;
      case SyncOperationType.receivableNote:
        return 3;
      case SyncOperationType.receivableSettlement:
        return 4;
    }
  }

  DateTime _sortTimestampFor(SyncOperation operation) {
    return operation.status == SyncRecordStatus.failed
        ? operation.updatedAt
        : operation.createdAt;
  }

  String? _readOptionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  String? _extractRemoteId(
    SyncOperationType type,
    Map<String, dynamic>? remoteData,
  ) {
    if (remoteData == null) {
      return null;
    }

    switch (type) {
      case SyncOperationType.sale:
        final sale = remoteData['sale'];
        if (sale is Map) {
          return sale['id'] as String?;
        }
        return null;
      case SyncOperationType.quickCustomer:
        final customer = remoteData['customer'];
        if (customer is Map) {
          return customer['id'] as String?;
        }
        return null;
      case SyncOperationType.cashMovement:
        return remoteData['id'] as String?;
      case SyncOperationType.receivableNote:
        final note = remoteData['note'];
        if (note is Map) {
          return note['id'] as String?;
        }
        return null;
      case SyncOperationType.receivableSettlement:
        final settlement = remoteData['settlement'];
        if (settlement is Map) {
          return settlement['id'] as String?;
        }
        return null;
    }
  }

  Future<void> _updateEntitySyncStatus({
    required LocalDatabaseExecutor executor,
    required SyncOperation operation,
    required SyncRecordStatus status,
    required String updatedAt,
    String? remoteId,
  }) async {
    switch (operation.type) {
      case SyncOperationType.quickCustomer:
        await executor.update(
          'quick_customers',
          <String, Object?>{
            'remote_id': remoteId,
            'sync_status': status.wireValue,
            'updated_at': updatedAt,
          },
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
      case SyncOperationType.cashMovement:
        await executor.update(
          'cash_movements',
          <String, Object?>{
            'remote_id': remoteId,
            'sync_status': status.wireValue,
          },
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
      case SyncOperationType.receivableNote:
        await executor.update(
          'payment_terms',
          <String, Object?>{
            'remote_id': remoteId,
            'sync_status': status.wireValue,
            'updated_at': updatedAt,
          },
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
      case SyncOperationType.receivableSettlement:
        await executor.update(
          'receivable_payments',
          <String, Object?>{
            'remote_id': remoteId,
            'sync_status': status.wireValue,
          },
          where: 'local_id = ?',
          whereArgs: <Object>[operation.entityLocalId],
        );
        break;
      case SyncOperationType.sale:
        break;
    }
  }

  Future<Map<String, Object?>?> _loadOperationRow(
    LocalDatabaseExecutor executor,
    String operationId,
  ) async {
    final rows = await executor.query(
      'sync_outbox',
      where: 'operation_id = ?',
      whereArgs: <Object>[operationId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  SyncOperation _mapOperation(Map<String, Object?> row) {
    return SyncOperation(
      operationId: row['operation_id']! as String,
      deviceId: row['device_id']! as String,
      companyId: row['company_id']! as String,
      type: SyncOperationType.fromWireValue(row['type']! as String),
      entityLocalId: row['entity_local_id']! as String,
      payload: (jsonDecode(row['payload_json']! as String) as Map)
          .cast<String, dynamic>(),
      status: SyncRecordStatus.fromWireValue(row['status']! as String),
      retries: row['retries']! as int,
      lastError: row['last_error'] as String?,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}

class _SyncDependencyKey {
  const _SyncDependencyKey._({required this.type, required this.localId});

  factory _SyncDependencyKey.quickCustomer(String localId) {
    return _SyncDependencyKey._(
      type: SyncOperationType.quickCustomer,
      localId: localId,
    );
  }

  factory _SyncDependencyKey.sale(String localId) {
    return _SyncDependencyKey._(type: SyncOperationType.sale, localId: localId);
  }

  factory _SyncDependencyKey.receivableNote(String localId) {
    return _SyncDependencyKey._(
      type: SyncOperationType.receivableNote,
      localId: localId,
    );
  }

  factory _SyncDependencyKey.operation(SyncOperationType type, String localId) {
    return _SyncDependencyKey._(type: type, localId: localId);
  }

  final SyncOperationType type;
  final String localId;

  @override
  bool operator ==(Object other) {
    return other is _SyncDependencyKey &&
        other.type == type &&
        other.localId == localId;
  }

  @override
  int get hashCode => Object.hash(type, localId);
}
