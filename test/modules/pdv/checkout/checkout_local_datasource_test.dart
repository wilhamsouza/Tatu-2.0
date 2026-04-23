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
import 'package:tatuzin/modules/pdv/checkout/application/dtos/checkout_request.dart';
import 'package:tatuzin/modules/pdv/checkout/data/datasources/local/checkout_local_datasource.dart';
import 'package:tatuzin/modules/pdv/payments/domain/entities/payment_method.dart';
import 'package:tatuzin/modules/pdv/quick_customer/data/datasources/local/quick_customer_local_datasource.dart';
import 'package:tatuzin/modules/pdv/receipts/data/datasources/local/receipt_local_datasource.dart';
import 'package:tatuzin/modules/pdv/cash_register/data/datasources/local/cash_register_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late CatalogLocalDatasource catalogDatasource;
  late QuickCustomerLocalDatasource quickCustomerDatasource;
  late CashRegisterLocalDatasource cashDatasource;
  late Directory receiptDirectory;
  late CheckoutLocalDatasource checkoutDatasource;
  late UserSession session;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'checkout-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();

    catalogDatasource = CatalogLocalDatasource(database: database);
    quickCustomerDatasource = QuickCustomerLocalDatasource(database: database);
    cashDatasource = CashRegisterLocalDatasource(database: database);
    receiptDirectory = await Directory(
      p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'receipts-test-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);

    checkoutDatasource = CheckoutLocalDatasource(
      database: database,
      quickCustomerLocalDatasource: quickCustomerDatasource,
      cashRegisterLocalDatasource: cashDatasource,
      receiptLocalDatasource: ReceiptLocalDatasource(
        directoryResolver: () async => receiptDirectory,
      ),
    );

    session = UserSession(
      user: const AppUser(
        userId: 'user_seller',
        name: 'Operador Teste',
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
      openingAmountInCents: 5000,
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

  test('persists offline cash sale, receipt and outbox entries', () async {
    final variants = await catalogDatasource.searchVariants(
      query: 'Camiseta Basica Preta',
    );
    final cart = Cart(
      items: <CartItem>[CartItem(variant: variants.first, quantity: 2)],
    );

    final result = await checkoutDatasource.completeCheckout(
      request: CheckoutRequest(
        cart: cart,
        paymentMethod: PaymentMethod.cash,
        amountReceivedInCents: 12000,
        pixConfirmedManually: false,
      ),
      session: session,
    );

    final db = await database.database;
    final payments = await db.query('payments');
    final receipts = await db.query('receipts');
    final outbox = await db.query('sync_outbox', orderBy: 'created_at ASC');

    expect(result.payment.changeInCents, 2020);
    expect(payments, hasLength(1));
    expect(receipts, hasLength(1));
    expect(File(result.receipt.pdfPath).existsSync(), isTrue);
    expect(
      outbox.map((entry) => entry['type']),
      containsAll(<Object?>['sale', 'cash_movement']),
    );
  });

  test('blocks note sale without due date', () async {
    final variants = await catalogDatasource.searchVariants(query: 'Jeans');
    final cart = Cart(
      items: <CartItem>[CartItem(variant: variants.first, quantity: 1)],
    );

    await expectLater(
      checkoutDatasource.completeCheckout(
        request: CheckoutRequest(
          cart: cart,
          paymentMethod: PaymentMethod.note,
          amountReceivedInCents: 0,
          pixConfirmedManually: false,
          customerName: 'Cliente Nota',
          customerPhone: '11999990000',
        ),
        session: session,
      ),
      throwsA(isA<CheckoutException>()),
    );
  });

  test('creates payment term and quick customer for note sale', () async {
    final variants = await catalogDatasource.searchVariants(query: 'Bolsa');
    final cart = Cart(
      items: <CartItem>[CartItem(variant: variants.single, quantity: 1)],
    );

    final result = await checkoutDatasource.completeCheckout(
      request: CheckoutRequest(
        cart: cart,
        paymentMethod: PaymentMethod.note,
        amountReceivedInCents: 0,
        pixConfirmedManually: false,
        noteDueDate: DateTime.utc(2026, 5, 20),
        customerName: 'Maria da Nota',
        customerPhone: '(11) 98888-7777',
      ),
      session: session,
    );

    final db = await database.database;
    final terms = await db.query('payment_terms');
    final customers = await db.query('quick_customers');
    final outbox = await db.query('sync_outbox');

    expect(result.paymentTerm, isNotNull);
    expect(result.paymentTerm!.outstandingAmountInCents, cart.totalInCents);
    expect(terms, hasLength(1));
    expect(customers, hasLength(1));
    expect(
      outbox.map((entry) => entry['type']),
      containsAll(<Object?>['sale', 'quick_customer', 'receivable_note']),
    );
  });
}
