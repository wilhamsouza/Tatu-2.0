import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/auth/domain/entities/app_user.dart';
import 'package:tatuzin/core/auth/domain/entities/auth_token_pair.dart';
import 'package:tatuzin/core/auth/domain/entities/user_session.dart';
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/device_identity/domain/entities/device_registration.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/core/networking/api_client.dart';
import 'package:tatuzin/core/permissions/domain/entities/app_role.dart';
import 'package:tatuzin/core/sync/application/services/sync_engine_service.dart';
import 'package:tatuzin/core/sync/data/datasources/local/sync_inbox_local_datasource.dart';
import 'package:tatuzin/core/sync/data/datasources/local/sync_outbox_local_datasource.dart';
import 'package:tatuzin/core/sync/data/datasources/remote/sync_remote_datasource.dart';
import 'package:tatuzin/core/sync/data/models/remote_sync_operation_result_dto.dart';
import 'package:tatuzin/core/sync/data/models/remote_sync_update_dto.dart';
import 'package:tatuzin/core/sync/data/models/remote_sync_updates_response_dto.dart';
import 'package:tatuzin/core/sync/domain/entities/inbox_update_type.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_operation.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_status_snapshot.dart';
import 'package:tatuzin/core/tenancy/domain/entities/company_context.dart';
import 'package:tatuzin/modules/pdv/cart/domain/entities/cart.dart';
import 'package:tatuzin/modules/pdv/cart/domain/entities/cart_item.dart';
import 'package:tatuzin/modules/pdv/catalog/data/datasources/local/catalog_local_datasource.dart';
import 'package:tatuzin/modules/pdv/cash_register/data/datasources/local/cash_register_local_datasource.dart';
import 'package:tatuzin/modules/pdv/checkout/application/dtos/checkout_request.dart';
import 'package:tatuzin/modules/pdv/checkout/data/datasources/local/checkout_local_datasource.dart';
import 'package:tatuzin/modules/pdv/payments/domain/entities/payment_method.dart';
import 'package:tatuzin/modules/pdv/quick_customer/data/datasources/local/quick_customer_local_datasource.dart';
import 'package:tatuzin/modules/pdv/receipts/data/datasources/local/receipt_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late CatalogLocalDatasource catalogDatasource;
  late CashRegisterLocalDatasource cashDatasource;
  late CheckoutLocalDatasource checkoutDatasource;
  late SyncOutboxLocalDatasource outboxDatasource;
  late SyncInboxLocalDatasource inboxDatasource;
  late Directory receiptDirectory;
  late UserSession session;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'sync-engine-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();

    catalogDatasource = CatalogLocalDatasource(database: database);
    cashDatasource = CashRegisterLocalDatasource(database: database);
    checkoutDatasource = CheckoutLocalDatasource(
      database: database,
      quickCustomerLocalDatasource: QuickCustomerLocalDatasource(
        database: database,
      ),
      cashRegisterLocalDatasource: cashDatasource,
      receiptLocalDatasource: ReceiptLocalDatasource(
        directoryResolver: () async => receiptDirectory,
      ),
    );
    outboxDatasource = SyncOutboxLocalDatasource(database: database);
    inboxDatasource = SyncInboxLocalDatasource(database: database);

    receiptDirectory = await Directory(
      p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'sync-engine-receipts-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);

    session = UserSession(
      user: const AppUser(
        userId: 'user_seller',
        name: 'Operador Sync',
        email: 'seller@tatuzin.app',
        roles: <AppRole>[AppRole.seller],
        companyId: 'company_tatuzin',
      ),
      tokens: AuthTokenPair(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
      ),
      companyContext: const CompanyContext(
        companyId: 'company_tatuzin',
        companyName: 'Tatuzin Moda',
      ),
      deviceRegistration: DeviceRegistration(
        deviceId: 'device_001',
        platform: 'android',
        registeredAt: DateTime.now().toUtc(),
      ),
      signedInAt: DateTime.now().toUtc(),
      syncStatus: const SyncStatusSnapshot(
        pendingOperations: 0,
        failedOperations: 0,
      ),
    );

    await catalogDatasource.ensureSeeded();
    await cashDatasource.openSession(
      companyId: session.companyContext.companyId,
      userId: session.user.userId,
      deviceId: session.deviceRegistration.deviceId,
      openingAmountInCents: 10000,
    );

    final variants = await catalogDatasource.searchVariants(query: 'Bolsa');
    await checkoutDatasource.completeCheckout(
      request: CheckoutRequest(
        cart: Cart(
          items: <CartItem>[CartItem(variant: variants.single, quantity: 1)],
        ),
        paymentMethod: PaymentMethod.note,
        amountReceivedInCents: 0,
        pixConfirmedManually: false,
        noteDueDate: DateTime.utc(2026, 5, 30),
        customerName: 'Maria Sync',
        customerPhone: '(11) 99999-0000',
      ),
      session: session,
    );
  });

  tearDown(() async {
    final path = await database.database.then((db) => db.path);
    await database.close();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    if (await receiptDirectory.exists()) {
      await receiptDirectory.delete(recursive: true);
    }
  });

  test(
    'runs one full sync cycle and marks pending operations as synced',
    () async {
      final pendingOperations = await outboxDatasource
          .loadOperationsForProcessing(limit: 20);

      final remoteDatasource = _FakeSyncRemoteDatasource(
        database: database,
        sendOutboxHandler: (operations) async {
          return operations.map((operation) {
            return RemoteSyncOperationResultDto(
              operationId: operation.operationId,
              type: operation.type.wireValue,
              entityLocalId: operation.entityLocalId,
              status: 'processed',
              data: switch (operation.type.wireValue) {
                'sale' => <String, dynamic>{
                  'sale': <String, dynamic>{
                    'id': 'sale_remote_${operation.entityLocalId}',
                  },
                },
                'quick_customer' => <String, dynamic>{
                  'customer': <String, dynamic>{
                    'id': 'customer_remote_${operation.entityLocalId}',
                  },
                },
                'cash_movement' => <String, dynamic>{
                  'id': 'cash_remote_${operation.entityLocalId}',
                },
                'receivable_note' => <String, dynamic>{
                  'note': <String, dynamic>{
                    'id': 'note_remote_${operation.entityLocalId}',
                  },
                },
                _ => null,
              },
            );
          }).toList();
        },
        updatesResponse: RemoteSyncUpdatesResponseDto(
          updates: <RemoteSyncUpdateDto>[
            RemoteSyncUpdateDto(
              cursor: '0005',
              updateType: InboxUpdateType.categorySnapshot,
              entityRemoteId: 'cat_sync_bridge',
              payload: <String, dynamic>{
                'id': 'cat_sync_bridge',
                'name': 'Sync Bridge',
                'updatedAt': '2026-04-21T10:00:00.000Z',
              },
              updatedAt: DateTime.parse('2026-04-21T10:00:00.000Z'),
            ),
          ],
          nextCursor: '0005',
        ),
      );

      final engine = SyncEngineService(
        outboxLocalDatasource: outboxDatasource,
        inboxLocalDatasource: inboxDatasource,
        remoteDatasource: remoteDatasource,
        database: database,
        logger: const AppLogger(),
      );

      final summary = await engine.runOnce(
        session: session,
        outboxBatchSize: 20,
      );

      final db = await database.database;
      final snapshot = await outboxDatasource.loadStatusSnapshot();
      final customers = await db.query('quick_customers');
      final sales = await db.query('sales');
      final paymentTerms = await db.query('payment_terms');
      final categories = await db.query(
        'categories_snapshot',
        where: 'remote_id = ?',
        whereArgs: <Object>['cat_sync_bridge'],
      );
      final cursor = await inboxDatasource.loadCursor();

      expect(summary.processedOperations, pendingOperations.length);
      expect(summary.syncedOperations, pendingOperations.length);
      expect(summary.failedOperations, 0);
      expect(summary.conflictOperations, 0);
      expect(summary.appliedUpdates, 1);
      expect(summary.receivedUpdates, 1);
      expect(snapshot.pendingOperations, 0);
      expect(snapshot.failedOperations, 0);
      expect(customers.single['remote_id'], isNotNull);
      expect(customers.single['sync_status'], 'synced');
      expect(sales.single['remote_id'], isNotNull);
      expect(sales.single['synced_at'], isNotNull);
      expect(paymentTerms.single['remote_id'], isNotNull);
      expect(paymentTerms.single['sync_status'], 'synced');
      expect(categories.single['name'], 'Sync Bridge');
      expect(cursor, '0005');
    },
  );
}

class _FakeSyncRemoteDatasource extends SyncRemoteDatasource {
  _FakeSyncRemoteDatasource({
    required AppDatabase database,
    required this.sendOutboxHandler,
    required this.updatesResponse,
  }) : super(
         apiClient: ApiClient(database: database, logger: const AppLogger()),
       );

  final Future<List<RemoteSyncOperationResultDto>> Function(
    List<SyncOperation> operations,
  )
  sendOutboxHandler;
  final RemoteSyncUpdatesResponseDto updatesResponse;

  @override
  Future<List<RemoteSyncOperationResultDto>> sendOutbox({
    required UserSession session,
    required List<SyncOperation> operations,
  }) async {
    return sendOutboxHandler(operations);
  }

  @override
  Future<RemoteSyncUpdatesResponseDto> fetchUpdates({
    required UserSession session,
    String? cursor,
    int limit = 50,
  }) async {
    return updatesResponse;
  }
}
