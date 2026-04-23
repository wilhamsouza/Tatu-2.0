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
import 'package:tatuzin/core/sync/domain/entities/sync_status_snapshot.dart';
import 'package:tatuzin/core/tenancy/domain/entities/company_context.dart';
import 'package:tatuzin/modules/pdv/cart/domain/entities/cart.dart';
import 'package:tatuzin/modules/pdv/cart/domain/entities/cart_item.dart';
import 'package:tatuzin/modules/pdv/catalog/data/datasources/local/catalog_local_datasource.dart';
import 'package:tatuzin/modules/pdv/cash_register/data/datasources/local/cash_register_local_datasource.dart';
import 'package:tatuzin/modules/pdv/checkout/application/dtos/checkout_request.dart';
import 'package:tatuzin/modules/pdv/checkout/data/datasources/local/checkout_local_datasource.dart';
import 'package:tatuzin/modules/pdv/local_dashboard/data/datasources/local/local_dashboard_local_datasource.dart';
import 'package:tatuzin/modules/pdv/payments/domain/entities/payment_method.dart';
import 'package:tatuzin/modules/pdv/quick_customer/data/datasources/local/quick_customer_local_datasource.dart';
import 'package:tatuzin/modules/pdv/receipts/data/datasources/local/receipt_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late CatalogLocalDatasource catalogDatasource;
  late CashRegisterLocalDatasource cashDatasource;
  late CheckoutLocalDatasource checkoutDatasource;
  late LocalDashboardLocalDatasource dashboardDatasource;
  late Directory receiptDirectory;
  late UserSession session;
  late String cashSessionLocalId;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'local-dashboard-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();

    catalogDatasource = CatalogLocalDatasource(database: database);
    cashDatasource = CashRegisterLocalDatasource(database: database);
    receiptDirectory = await Directory(
      p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'local-dashboard-receipts-${DateTime.now().microsecondsSinceEpoch}',
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
    dashboardDatasource = LocalDashboardLocalDatasource(database: database);

    session = UserSession(
      user: const AppUser(
        userId: 'user_cashier',
        name: 'Caixa Teste',
        email: 'cashier@tatuzin.app',
        roles: <AppRole>[AppRole.cashier],
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
    final opened = await cashDatasource.openSession(
      companyId: session.companyContext.companyId,
      userId: session.user.userId,
      deviceId: session.deviceRegistration.deviceId,
      openingAmountInCents: 10000,
    );
    cashSessionLocalId = opened.session.localId;
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

  test('aggregates session indicators and recent local sales', () async {
    final cashVariants = await catalogDatasource.searchVariants(
      query: 'Camiseta',
    );
    final noteVariants = await catalogDatasource.searchVariants(query: 'Bolsa');

    await checkoutDatasource.completeCheckout(
      request: CheckoutRequest(
        cart: Cart(
          items: <CartItem>[CartItem(variant: cashVariants.first, quantity: 2)],
        ),
        paymentMethod: PaymentMethod.cash,
        amountReceivedInCents: 12000,
        pixConfirmedManually: false,
      ),
      session: session,
    );

    await checkoutDatasource.completeCheckout(
      request: CheckoutRequest(
        cart: Cart(
          items: <CartItem>[
            CartItem(variant: noteVariants.single, quantity: 1),
          ],
        ),
        paymentMethod: PaymentMethod.note,
        amountReceivedInCents: 0,
        pixConfirmedManually: false,
        noteDueDate: DateTime.utc(2026, 5, 30),
        customerName: 'Cliente Painel',
        customerPhone: '11999998888',
      ),
      session: session,
    );

    final snapshot = await dashboardDatasource.loadSnapshotForCashSession(
      cashSessionLocalId,
    );

    expect(snapshot.summary.totalSales, 2);
    expect(snapshot.summary.totalItemsSold, 3);
    expect(snapshot.summary.cashSalesInCents, greaterThan(0));
    expect(snapshot.summary.noteSalesInCents, greaterThan(0));
    expect(snapshot.summary.outstandingNoteAmountInCents, greaterThan(0));
    expect(snapshot.recentSales, hasLength(2));
    expect(
      snapshot.recentSales.any(
        (sale) => sale.paymentMethod == PaymentMethod.note,
      ),
      isTrue,
    );
  });
}
