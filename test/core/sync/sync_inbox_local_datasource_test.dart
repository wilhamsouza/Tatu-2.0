import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/core/sync/data/datasources/local/sync_inbox_local_datasource.dart';
import 'package:tatuzin/core/sync/data/models/remote_sync_update_dto.dart';
import 'package:tatuzin/core/sync/domain/entities/inbox_update_type.dart';

void main() {
  late AppDatabase database;
  late SyncInboxLocalDatasource datasource;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'sync-inbox-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();
    datasource = SyncInboxLocalDatasource(database: database);
  });

  tearDown(() async {
    final path = await database.database.then((db) => db.path);
    await database.close();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test(
    'persists incremental updates and applies them to the local catalog',
    () async {
      final updates = <RemoteSyncUpdateDto>[
        RemoteSyncUpdateDto(
          cursor: '0001',
          updateType: InboxUpdateType.categorySnapshot,
          entityRemoteId: 'cat_basicos',
          payload: <String, dynamic>{
            'id': 'cat_basicos',
            'name': 'Basicos',
            'updatedAt': '2026-04-21T09:00:00.000Z',
          },
          updatedAt: DateTime.parse('2026-04-21T09:00:00.000Z'),
        ),
        RemoteSyncUpdateDto(
          cursor: '0002',
          updateType: InboxUpdateType.productSnapshot,
          entityRemoteId: 'prod_camiseta_oversized',
          payload: <String, dynamic>{
            'id': 'prod_camiseta_oversized',
            'name': 'Camiseta Oversized',
            'categoryName': 'Basicos',
            'isActive': true,
            'updatedAt': '2026-04-21T09:01:00.000Z',
          },
          updatedAt: DateTime.parse('2026-04-21T09:01:00.000Z'),
        ),
        RemoteSyncUpdateDto(
          cursor: '0003',
          updateType: InboxUpdateType.variantSnapshot,
          entityRemoteId: 'var_camiseta_oversized_preta_m',
          payload: <String, dynamic>{
            'id': 'var_camiseta_oversized_preta_m',
            'productId': 'prod_camiseta_oversized',
            'barcode': '7891000000011',
            'sku': 'CAM-OVR-PRT-M',
            'displayName': 'Camiseta Oversized Preta M',
            'shortName': 'Oversized Preta M',
            'color': 'Preta',
            'size': 'M',
            'categoryName': 'Basicos',
            'priceInCents': 9900,
            'promotionalPriceInCents': 8900,
            'imageUrl': null,
            'imageLocalPath': null,
            'isActiveForSale': true,
            'updatedAt': '2026-04-21T09:02:00.000Z',
          },
          updatedAt: DateTime.parse('2026-04-21T09:02:00.000Z'),
        ),
        RemoteSyncUpdateDto(
          cursor: '0004',
          updateType: InboxUpdateType.priceSnapshot,
          entityRemoteId: 'price_var_camiseta_oversized_preta_m',
          payload: <String, dynamic>{
            'id': 'price_var_camiseta_oversized_preta_m',
            'variantRemoteId': 'var_camiseta_oversized_preta_m',
            'priceInCents': 9900,
            'promotionalPriceInCents': 8900,
            'startsAt': null,
            'endsAt': null,
            'updatedAt': '2026-04-21T09:03:00.000Z',
          },
          updatedAt: DateTime.parse('2026-04-21T09:03:00.000Z'),
        ),
      ];

      await datasource.persistUpdates(updates);
      final applied = await datasource.applyPendingUpdates(nextCursor: '0004');

      final db = await database.database;
      final categories = await db.query('categories_snapshot');
      final products = await db.query('products_snapshot');
      final variants = await db.query('product_variants_snapshot');
      final prices = await db.query('price_rules_snapshot');
      final logs = await db.query('sync_logs', orderBy: 'id ASC');
      final cursor = await datasource.loadCursor();

      expect(applied, 4);
      expect(categories.single['name'], 'Basicos');
      expect(products.single['name'], 'Camiseta Oversized');
      expect(variants.single['display_name'], 'Camiseta Oversized Preta M');
      expect(
        prices.single['variant_remote_id'],
        'var_camiseta_oversized_preta_m',
      );
      expect(logs, hasLength(2));
      expect(logs[0]['message'], 'Remote updates persisted in inbox.');
      expect(logs[1]['message'], 'Inbox updates applied locally.');
      expect(cursor, '0004');
    },
  );
}
