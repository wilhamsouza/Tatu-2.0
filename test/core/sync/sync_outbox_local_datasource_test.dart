import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/auth/domain/entities/app_user.dart';
import 'package:tatuzin/core/auth/domain/entities/auth_token_pair.dart';
import 'package:tatuzin/core/auth/domain/entities/user_session.dart';
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/device_identity/domain/entities/device_registration.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/core/permissions/domain/entities/app_role.dart';
import 'package:tatuzin/core/sync/data/datasources/local/sync_outbox_local_datasource.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_operation_type.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_record_status.dart';
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
  late SyncOutboxLocalDatasource syncOutboxDatasource;
  late Directory receiptDirectory;
  late UserSession session;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'sync-outbox-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();

    catalogDatasource = CatalogLocalDatasource(database: database);
    cashDatasource = CashRegisterLocalDatasource(database: database);
    syncOutboxDatasource = SyncOutboxLocalDatasource(database: database);

    receiptDirectory = await Directory(
      p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'sync-outbox-receipts-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);

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

  test('marks sync results and updates local entities', () async {
    final operations = await syncOutboxDatasource.loadOperationsForProcessing(
      limit: 10,
    );

    final quickCustomerOperation = operations.firstWhere(
      (operation) => operation.type == SyncOperationType.quickCustomer,
    );
    final saleOperation = operations.firstWhere(
      (operation) => operation.type == SyncOperationType.sale,
    );
    final receivableOperation = operations.firstWhere(
      (operation) => operation.type == SyncOperationType.receivableNote,
    );

    await syncOutboxDatasource.markOperationSynced(
      operation: quickCustomerOperation,
      remoteData: <String, dynamic>{
        'customer': <String, dynamic>{'id': 'customer_remote_001'},
      },
    );
    await syncOutboxDatasource.markOperationSynced(
      operation: saleOperation,
      remoteData: <String, dynamic>{
        'sale': <String, dynamic>{'id': 'sale_remote_001'},
      },
    );
    await syncOutboxDatasource.markOperationConflict(
      operation: receivableOperation,
      conflictType: 'sale_missing',
      errorMessage: 'Nota aguardando consolidacao remota da venda.',
    );

    final db = await database.database;
    final customers = await db.query('quick_customers');
    final sales = await db.query('sales');
    final terms = await db.query('payment_terms');
    final conflicts = await db.query('sync_conflicts');
    final logs = await db.query('sync_logs', orderBy: 'id ASC');

    expect(customers.single['remote_id'], 'customer_remote_001');
    expect(customers.single['sync_status'], SyncRecordStatus.synced.wireValue);
    expect(sales.single['remote_id'], 'sale_remote_001');
    expect(sales.single['synced_at'], isNotNull);
    expect(terms.single['sync_status'], SyncRecordStatus.conflict.wireValue);
    expect(conflicts, hasLength(1));
    expect(logs, hasLength(3));
    expect(logs[0]['message'], 'Outbox operation synced successfully.');
    expect(logs[1]['message'], 'Outbox operation synced successfully.');
    expect(logs[2]['message'], 'Outbox operation moved to conflict.');
  });

  test('orders outbox operations according to local dependencies', () async {
    final operations = await syncOutboxDatasource.loadOperationsForProcessing(
      limit: 10,
    );

    final quickCustomerIndex = operations.indexWhere(
      (operation) => operation.type == SyncOperationType.quickCustomer,
    );
    final saleIndex = operations.indexWhere(
      (operation) => operation.type == SyncOperationType.sale,
    );
    final receivableIndex = operations.indexWhere(
      (operation) => operation.type == SyncOperationType.receivableNote,
    );
    final saleLocalId = operations[saleIndex].entityLocalId;
    final saleCashMovementIndex = operations.indexWhere(
      (operation) =>
          operation.type == SyncOperationType.cashMovement &&
          operation.payload['saleLocalId'] == saleLocalId,
    );

    expect(quickCustomerIndex, greaterThanOrEqualTo(0));
    expect(saleIndex, greaterThan(quickCustomerIndex));
    expect(saleCashMovementIndex, greaterThan(saleIndex));
    expect(receivableIndex, greaterThan(saleIndex));
  });

  test(
    'waits for retry-ready parents before selecting dependent operations',
    () async {
      final initialOperations = await syncOutboxDatasource
          .loadOperationsForProcessing(limit: 10);
      final quickCustomerOperation = initialOperations.firstWhere(
        (operation) => operation.type == SyncOperationType.quickCustomer,
      );

      await syncOutboxDatasource.markOperationFailed(
        operation: quickCustomerOperation,
        errorMessage: 'Cliente aguardando retry automatico.',
      );

      final blockedOperations = await syncOutboxDatasource
          .loadOperationsForProcessing(limit: 10);

      expect(
        blockedOperations.any(
          (operation) => operation.type == SyncOperationType.sale,
        ),
        isFalse,
      );
      expect(
        blockedOperations.any(
          (operation) => operation.type == SyncOperationType.receivableNote,
        ),
        isFalse,
      );
      expect(
        blockedOperations.any(
          (operation) =>
              operation.type == SyncOperationType.cashMovement &&
              operation.payload['saleLocalId'] != null,
        ),
        isFalse,
      );

      final db = await database.database;
      await db.update(
        'sync_outbox',
        <String, Object?>{
          'updated_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        },
        where: 'operation_id = ?',
        whereArgs: <Object>[quickCustomerOperation.operationId],
      );

      final retryReadyOperations = await syncOutboxDatasource
          .loadOperationsForProcessing(limit: 10);
      final retryQuickCustomerIndex = retryReadyOperations.indexWhere(
        (operation) =>
            operation.operationId == quickCustomerOperation.operationId,
      );
      final saleIndex = retryReadyOperations.indexWhere(
        (operation) => operation.type == SyncOperationType.sale,
      );

      expect(retryQuickCustomerIndex, greaterThanOrEqualTo(0));
      expect(saleIndex, greaterThan(retryQuickCustomerIndex));
    },
  );
}
