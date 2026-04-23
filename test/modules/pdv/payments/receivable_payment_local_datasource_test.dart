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
import 'package:tatuzin/core/sync/domain/entities/sync_record_status.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_status_snapshot.dart';
import 'package:tatuzin/core/tenancy/domain/entities/company_context.dart';
import 'package:tatuzin/modules/pdv/cart/domain/entities/cart.dart';
import 'package:tatuzin/modules/pdv/cart/domain/entities/cart_item.dart';
import 'package:tatuzin/modules/pdv/catalog/data/datasources/local/catalog_local_datasource.dart';
import 'package:tatuzin/modules/pdv/cash_register/data/datasources/local/cash_register_local_datasource.dart';
import 'package:tatuzin/modules/pdv/checkout/application/dtos/checkout_request.dart';
import 'package:tatuzin/modules/pdv/checkout/data/datasources/local/checkout_local_datasource.dart';
import 'package:tatuzin/modules/pdv/payments/data/datasources/local/receivable_payment_local_datasource.dart';
import 'package:tatuzin/modules/pdv/payments/domain/entities/payment_method.dart';
import 'package:tatuzin/modules/pdv/payments/domain/entities/settlement_payment_method.dart';
import 'package:tatuzin/modules/pdv/quick_customer/data/datasources/local/quick_customer_local_datasource.dart';
import 'package:tatuzin/modules/pdv/receipts/data/datasources/local/receipt_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late CatalogLocalDatasource catalogDatasource;
  late CashRegisterLocalDatasource cashDatasource;
  late CheckoutLocalDatasource checkoutDatasource;
  late ReceivablePaymentLocalDatasource receivablePaymentDatasource;
  late Directory receiptDirectory;
  late UserSession session;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'receivable-payment-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();

    catalogDatasource = CatalogLocalDatasource(database: database);
    cashDatasource = CashRegisterLocalDatasource(database: database);
    receiptDirectory = await Directory(
      p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'receivable-payment-receipts-${DateTime.now().microsecondsSinceEpoch}',
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
    receivablePaymentDatasource = ReceivablePaymentLocalDatasource(
      database: database,
      cashRegisterLocalDatasource: cashDatasource,
    );

    session = UserSession(
      user: const AppUser(
        userId: 'user_cashier',
        name: 'Operador Caixa',
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
        customerName: 'Maria Baixa',
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

  test('registers partial note settlement in current cash session', () async {
    final db = await database.database;
    final paymentTerm = (await db.query('payment_terms')).single;
    final openSession = await cashDatasource.loadOpenSessionSummary();

    final payment = await receivablePaymentDatasource.registerSettlement(
      companyId: session.companyContext.companyId,
      userId: session.user.userId,
      deviceId: session.deviceRegistration.deviceId,
      paymentTermLocalId: paymentTerm['local_id']! as String,
      cashSessionLocalId: openSession!.session.localId,
      amountInCents: 4000,
      settlementMethod: SettlementPaymentMethod.cash,
      notes: 'Entrada parcial',
      paidAt: DateTime.utc(2026, 4, 22, 10),
    );

    final updatedTerms = await db.query('payment_terms');
    final receivablePayments = await db.query('receivable_payments');
    final cashMovements = await db.query(
      'cash_movements',
      where: 'type = ?',
      whereArgs: <Object>['receivable_settlement_cash'],
    );
    final outbox = await db.query(
      'sync_outbox',
      where: 'type = ?',
      whereArgs: <Object>['receivable_settlement'],
    );
    final summary = await cashDatasource.loadOpenSessionSummary();

    expect(payment.amountInCents, 4000);
    expect(receivablePayments.single['local_id'], payment.localId);
    final originalAmountInCents = paymentTerm['original_amount_cents']! as int;

    expect(updatedTerms.single['paid_amount_cents'], 4000);
    expect(
      updatedTerms.single['outstanding_amount_cents'],
      originalAmountInCents - 4000,
    );
    expect(updatedTerms.single['payment_status'], 'partially_paid');
    expect(
      updatedTerms.single['sync_status'],
      SyncRecordStatus.pending.wireValue,
    );
    expect(cashMovements.single['amount_cents'], 4000);
    expect(outbox, hasLength(1));
    expect(summary!.receivableSettlementCashInCents, 4000);
    expect(summary.expectedCashBalanceInCents, 14000);
  });
}
