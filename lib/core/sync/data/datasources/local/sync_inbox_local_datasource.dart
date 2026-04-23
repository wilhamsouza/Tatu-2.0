import 'dart:convert';

import '../../../../database/app_database.dart';
import '../../../../database/local_database_executor.dart';
import '../../models/remote_sync_update_dto.dart';
import '../../../domain/entities/inbox_update_type.dart';

class SyncInboxLocalDatasource {
  const SyncInboxLocalDatasource({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<String?> loadCursor() async {
    final db = await _database.database;
    final rows = await db.query(
      'sync_cursor',
      where: 'id = ?',
      whereArgs: <Object>[1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['cursor_value'] as String?;
  }

  Future<void> persistUpdates(List<RemoteSyncUpdateDto> updates) async {
    if (updates.isEmpty) {
      return;
    }

    final db = await _database.database;
    final receivedAt = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final update in updates) {
        await txn.insert('sync_inbox', <String, Object?>{
          'update_type': update.updateType.wireValue,
          'entity_remote_id': update.entityRemoteId,
          'payload_json': jsonEncode(<String, Object?>{
            'cursor': update.cursor,
            'payload': update.payload,
            'updatedAt': update.updatedAt.toIso8601String(),
          }),
          'received_at': receivedAt,
          'applied_at': null,
        });
      }

      await _database.appendSyncLogWithExecutor(
        executor: txn,
        level: 'info',
        message: 'Remote updates persisted in inbox.',
        context: <String, Object?>{
          'count': updates.length,
          'firstCursor': updates.first.cursor,
          'lastCursor': updates.last.cursor,
        },
      );
    });
  }

  Future<int> applyPendingUpdates({String? nextCursor}) async {
    final db = await _database.database;
    final rows = await db.query(
      'sync_inbox',
      where: 'applied_at IS NULL',
      orderBy: 'id ASC',
    );

    if (rows.isEmpty) {
      if (nextCursor != null) {
        await _saveCursor(db, nextCursor);
      }
      return 0;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final row in rows) {
        await _applyUpdate(txn, row);
        await txn.update(
          'sync_inbox',
          <String, Object?>{'applied_at': now},
          where: 'id = ?',
          whereArgs: <Object>[row['id']! as int],
        );
      }

      if (nextCursor != null) {
        await _saveCursor(txn, nextCursor);
      }

      await _database.appendSyncLogWithExecutor(
        executor: txn,
        level: 'info',
        message: 'Inbox updates applied locally.',
        context: <String, Object?>{
          'count': rows.length,
          'nextCursor': nextCursor,
        },
      );
    });

    return rows.length;
  }

  Future<void> _applyUpdate(
    LocalDatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final updateType = InboxUpdateType.fromWireValue(
      row['update_type']! as String,
    );
    final payloadEnvelope = (jsonDecode(row['payload_json']! as String) as Map)
        .cast<String, dynamic>();
    final payload = (payloadEnvelope['payload'] as Map).cast<String, dynamic>();

    switch (updateType) {
      case InboxUpdateType.categorySnapshot:
        await _upsertCategory(executor, payload);
        break;
      case InboxUpdateType.productSnapshot:
        await _upsertProduct(executor, payload);
        break;
      case InboxUpdateType.variantSnapshot:
        await _upsertVariant(executor, payload);
        break;
      case InboxUpdateType.priceSnapshot:
        await _upsertPriceRule(executor, payload);
        break;
      case InboxUpdateType.customerMergeOrEnrichment:
        break;
    }
  }

  Future<void> _upsertCategory(
    LocalDatabaseExecutor executor,
    Map<String, dynamic> payload,
  ) async {
    final remoteId = payload['id'] as String;
    final existing = await _findByRemoteId(
      executor: executor,
      table: 'categories_snapshot',
      remoteId: remoteId,
    );

    final values = <String, Object?>{
      'remote_id': remoteId,
      'name': payload['name'] as String,
      'updated_at': payload['updatedAt'] as String,
    };

    if (existing == null) {
      await executor.insert('categories_snapshot', values);
      return;
    }

    await executor.update(
      'categories_snapshot',
      values,
      where: 'local_id = ?',
      whereArgs: <Object>[existing['local_id']! as int],
    );
  }

  Future<void> _upsertProduct(
    LocalDatabaseExecutor executor,
    Map<String, dynamic> payload,
  ) async {
    final remoteId = payload['id'] as String;
    final existing = await _findByRemoteId(
      executor: executor,
      table: 'products_snapshot',
      remoteId: remoteId,
    );

    final values = <String, Object?>{
      'remote_id': remoteId,
      'name': payload['name'] as String,
      'category_name': payload['categoryName'] as String?,
      'is_active': _asSqlBool(payload['isActive']),
      'updated_at': payload['updatedAt'] as String,
    };

    if (existing == null) {
      await executor.insert('products_snapshot', values);
      return;
    }

    await executor.update(
      'products_snapshot',
      values,
      where: 'local_id = ?',
      whereArgs: <Object>[existing['local_id']! as int],
    );
  }

  Future<void> _upsertVariant(
    LocalDatabaseExecutor executor,
    Map<String, dynamic> payload,
  ) async {
    final remoteId = payload['id'] as String;
    final existing = await _findByRemoteId(
      executor: executor,
      table: 'product_variants_snapshot',
      remoteId: remoteId,
    );

    final values = <String, Object?>{
      'remote_id': remoteId,
      'product_remote_id': payload['productId'] as String?,
      'barcode': payload['barcode'] as String?,
      'sku': payload['sku'] as String?,
      'display_name': payload['displayName'] as String,
      'short_name': payload['shortName'] as String?,
      'color': payload['color'] as String?,
      'size': payload['size'] as String?,
      'category_name': payload['categoryName'] as String?,
      'price_cents': payload['priceInCents'] as int,
      'promotional_price_cents': payload['promotionalPriceInCents'] as int?,
      'image_url': payload['imageUrl'] as String?,
      'image_local_path': payload['imageLocalPath'] as String?,
      'is_active_for_sale': _asSqlBool(payload['isActiveForSale']),
      'updated_at': payload['updatedAt'] as String,
    };

    if (existing == null) {
      await executor.insert('product_variants_snapshot', values);
      return;
    }

    await executor.update(
      'product_variants_snapshot',
      values,
      where: 'local_id = ?',
      whereArgs: <Object>[existing['local_id']! as int],
    );
  }

  Future<void> _upsertPriceRule(
    LocalDatabaseExecutor executor,
    Map<String, dynamic> payload,
  ) async {
    final remoteId = payload['id'] as String;
    final existing = await _findByRemoteId(
      executor: executor,
      table: 'price_rules_snapshot',
      remoteId: remoteId,
    );

    final values = <String, Object?>{
      'remote_id': remoteId,
      'variant_remote_id': payload['variantRemoteId'] as String,
      'price_cents': payload['priceInCents'] as int,
      'promotional_price_cents': payload['promotionalPriceInCents'] as int?,
      'starts_at': payload['startsAt'] as String?,
      'ends_at': payload['endsAt'] as String?,
      'updated_at': payload['updatedAt'] as String,
    };

    if (existing == null) {
      await executor.insert('price_rules_snapshot', values);
      return;
    }

    await executor.update(
      'price_rules_snapshot',
      values,
      where: 'local_id = ?',
      whereArgs: <Object>[existing['local_id']! as int],
    );
  }

  Future<Map<String, Object?>?> _findByRemoteId({
    required LocalDatabaseExecutor executor,
    required String table,
    required String remoteId,
  }) async {
    final rows = await executor.query(
      table,
      where: 'remote_id = ?',
      whereArgs: <Object>[remoteId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _saveCursor(
    LocalDatabaseExecutor executor,
    String nextCursor,
  ) async {
    await executor.insert('sync_cursor', <String, Object?>{
      'id': 1,
      'cursor_value': nextCursor,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: LocalConflictAlgorithm.replace);
  }

  int _asSqlBool(dynamic value) {
    return value == true ? 1 : 0;
  }
}
