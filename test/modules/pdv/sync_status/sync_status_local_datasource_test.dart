import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/core/networking/api_client.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_record_status.dart';
import 'package:tatuzin/modules/pdv/sync_status/data/datasources/local/sync_status_local_datasource.dart';

void main() {
  late AppDatabase database;
  late SyncStatusLocalDatasource datasource;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'sync-status-details-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();

    final apiClient = ApiClient(
      database: database,
      logger: const AppLogger(),
      defaultBaseUrl: 'http://sync.test:3333',
    );
    datasource = SyncStatusLocalDatasource(
      database: database,
      apiClient: apiClient,
    );
  });

  tearDown(() async {
    final path = await database.database.then((db) => db.path);
    await database.close();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('loads endpoint configuration, cursor, conflicts and logs', () async {
    await database.saveAppSetting(
      key: ApiClient.apiBaseUrlSettingKey,
      value: 'http://custom-sync.test:4444',
    );
    await database.appendSyncLog(
      level: 'info',
      message: 'Sync cycle finished.',
      context: <String, Object?>{'syncedOperations': 2},
    );

    final db = await database.database;
    await db.insert('sync_cursor', <String, Object?>{
      'id': 1,
      'cursor_value': '0004',
      'updated_at': '2026-04-21T12:00:00.000Z',
    });
    await db.insert('sync_conflicts', <String, Object?>{
      'operation_id': 'operation_001',
      'conflict_type': 'sale_missing',
      'details_json': '{"message":"Venda ainda nao consolidada."}',
      'created_at': '2026-04-21T12:01:00.000Z',
    });
    await db.insert('sync_outbox', <String, Object?>{
      'operation_id': 'operation_001',
      'device_id': 'device_001',
      'company_id': 'company_tatuzin',
      'type': 'sale',
      'entity_local_id': 'sale_local_conflict',
      'payload_json': '{}',
      'status': SyncRecordStatus.conflict.wireValue,
      'retries': 1,
      'last_error': 'sale_missing',
      'created_at': '2026-04-21T12:01:00.000Z',
      'updated_at': '2026-04-21T12:01:00.000Z',
    });
    await db.insert('sync_outbox', <String, Object?>{
      'operation_id': 'op_pending',
      'device_id': 'device_001',
      'company_id': 'company_tatuzin',
      'type': 'sale',
      'entity_local_id': 'sale_local_001',
      'payload_json': '{}',
      'status': SyncRecordStatus.pending.wireValue,
      'retries': 0,
      'last_error': null,
      'created_at': '2026-04-21T12:02:00.000Z',
      'updated_at': '2026-04-21T12:02:00.000Z',
    });
    await db.insert('quick_customers', <String, Object?>{
      'local_id': 'customer_local_001',
      'remote_id': null,
      'name': 'Maria Sync',
      'phone': '11999990000',
      'sync_status': SyncRecordStatus.failed.wireValue,
      'created_at': '2026-04-21T11:59:00.000Z',
      'updated_at': '2026-04-21T12:02:00.000Z',
    });
    await db.insert('sync_outbox', <String, Object?>{
      'operation_id': 'op_synced',
      'device_id': 'device_001',
      'company_id': 'company_tatuzin',
      'type': 'quick_customer',
      'entity_local_id': 'customer_local_001',
      'payload_json': '{}',
      'status': SyncRecordStatus.synced.wireValue,
      'retries': 0,
      'last_error': null,
      'created_at': '2026-04-21T12:03:00.000Z',
      'updated_at': '2026-04-21T12:03:00.000Z',
    });

    final details = await datasource.loadDetails();

    expect(details.customApiBaseUrl, 'http://custom-sync.test:4444');
    expect(details.effectiveApiBaseUrl, 'http://custom-sync.test:4444');
    expect(details.cursor, '0004');
    expect(details.snapshot.pendingOperations, 1);
    expect(details.snapshot.failedOperations, 1);
    expect(details.snapshot.lastSuccessfulSyncAt, isNotNull);
    expect(details.recentConflicts, hasLength(1));
    expect(details.recentConflicts.single.conflictType, 'sale_missing');
    expect(details.recentLogs, isNotEmpty);
    expect(details.recentLogs.first.message, 'Sync cycle finished.');
    expect(details.recentOperations, hasLength(3));
    expect(details.recentOperations.first.operationId, 'op_synced');
  });

  test(
    'retries a single conflicted operation and bulk retries failed issues',
    () async {
      final db = await database.database;
      await db.insert('payment_terms', <String, Object?>{
        'local_id': 'term_local_001',
        'sale_local_id': 'sale_local_001',
        'remote_id': null,
        'customer_local_id': null,
        'customer_remote_id': null,
        'payment_method': 'note',
        'original_amount_cents': 15000,
        'paid_amount_cents': 0,
        'outstanding_amount_cents': 15000,
        'due_date': '2026-05-10T00:00:00.000Z',
        'payment_status': 'pending',
        'notes': null,
        'sync_status': SyncRecordStatus.conflict.wireValue,
        'created_at': '2026-04-21T11:59:00.000Z',
        'updated_at': '2026-04-21T12:00:00.000Z',
      });
      await db.insert('quick_customers', <String, Object?>{
        'local_id': 'customer_local_002',
        'remote_id': null,
        'name': 'Ana Retry',
        'phone': '11999991111',
        'sync_status': SyncRecordStatus.failed.wireValue,
        'created_at': '2026-04-21T11:59:00.000Z',
        'updated_at': '2026-04-21T12:01:00.000Z',
      });
      await db.insert('sync_outbox', <String, Object?>{
        'operation_id': 'op_conflict',
        'device_id': 'device_001',
        'company_id': 'company_tatuzin',
        'type': 'receivable_note',
        'entity_local_id': 'term_local_001',
        'payload_json': '{}',
        'status': SyncRecordStatus.conflict.wireValue,
        'retries': 2,
        'last_error': 'sale_missing',
        'created_at': '2026-04-21T12:00:00.000Z',
        'updated_at': '2026-04-21T12:00:00.000Z',
      });
      await db.insert('sync_outbox', <String, Object?>{
        'operation_id': 'op_failed',
        'device_id': 'device_001',
        'company_id': 'company_tatuzin',
        'type': 'quick_customer',
        'entity_local_id': 'customer_local_002',
        'payload_json': '{}',
        'status': SyncRecordStatus.failed.wireValue,
        'retries': 3,
        'last_error': 'timeout',
        'created_at': '2026-04-21T12:01:00.000Z',
        'updated_at': '2026-04-21T12:01:00.000Z',
      });

      await datasource.retryOperation('op_conflict');
      final retriedCount = await datasource.retryIssueOperations();

      final outboxRows = await db.query(
        'sync_outbox',
        orderBy: 'operation_id ASC',
      );
      final paymentTerms = await db.query('payment_terms');
      final customers = await db.query('quick_customers');
      final logs = await db.query('sync_logs', orderBy: 'id ASC');

      expect(retriedCount, 1);
      expect(outboxRows[0]['status'], SyncRecordStatus.pending.wireValue);
      expect(outboxRows[0]['retries'], 0);
      expect(outboxRows[0]['last_error'], isNull);
      expect(outboxRows[1]['status'], SyncRecordStatus.pending.wireValue);
      expect(outboxRows[1]['retries'], 0);
      expect(
        paymentTerms.single['sync_status'],
        SyncRecordStatus.pending.wireValue,
      );
      expect(
        customers.single['sync_status'],
        SyncRecordStatus.pending.wireValue,
      );
      expect(logs, hasLength(2));
      expect(logs[0]['message'], 'Single operation moved back to pending.');
      expect(logs[1]['message'], 'Issue operations moved back to pending.');
    },
  );
}
