import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
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
import 'package:tatuzin/core/sync/domain/entities/sync_operation_type.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_record_status.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_status_snapshot.dart';
import 'package:tatuzin/core/tenancy/domain/entities/company_context.dart';
import 'package:tatuzin/modules/pdv/cart/domain/entities/cart.dart';
import 'package:tatuzin/modules/pdv/cart/domain/entities/cart_item.dart';
import 'package:tatuzin/modules/pdv/cash_register/data/datasources/local/cash_register_local_datasource.dart';
import 'package:tatuzin/modules/pdv/cash_register/domain/entities/cash_movement_type.dart';
import 'package:tatuzin/modules/pdv/catalog/data/datasources/local/catalog_local_datasource.dart';
import 'package:tatuzin/modules/pdv/checkout/application/dtos/checkout_request.dart';
import 'package:tatuzin/modules/pdv/checkout/data/datasources/local/checkout_local_datasource.dart';
import 'package:tatuzin/modules/pdv/payments/domain/entities/payment_method.dart';
import 'package:tatuzin/modules/pdv/quick_customer/data/datasources/local/quick_customer_local_datasource.dart';
import 'package:tatuzin/modules/pdv/receipts/data/datasources/local/receipt_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _BackendHarness backend;
  late AppDatabase database;
  late CatalogLocalDatasource catalogDatasource;
  late CashRegisterLocalDatasource cashDatasource;
  late CheckoutLocalDatasource checkoutDatasource;
  late SyncOutboxLocalDatasource outboxDatasource;
  late SyncInboxLocalDatasource inboxDatasource;
  late Directory receiptDirectory;
  late ApiClient backendApiClient;
  late SyncRemoteDatasource remoteDatasource;
  late UserSession session;

  setUpAll(() async {
    backend = await _BackendHarness.start();
  });

  tearDownAll(() async {
    await backend.stop();
  });

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'offline-note-sync-regression-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();

    catalogDatasource = CatalogLocalDatasource(database: database);
    cashDatasource = CashRegisterLocalDatasource(database: database);
    receiptDirectory = await Directory(
      p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'offline-note-sync-receipts-${DateTime.now().microsecondsSinceEpoch}',
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
    outboxDatasource = SyncOutboxLocalDatasource(database: database);
    inboxDatasource = SyncInboxLocalDatasource(database: database);
    backendApiClient = ApiClient(
      database: database,
      logger: const AppLogger(),
      httpClient: IOClient(_createRealHttpClient()),
      defaultBaseUrl: backend.baseUrl,
    );
    remoteDatasource = SyncRemoteDatasource(apiClient: backendApiClient);

    session = UserSession(
      user: const AppUser(
        userId: 'user_cashier',
        name: 'Operador de Caixa',
        email: 'cashier@tatuzin.app',
        roles: <AppRole>[AppRole.cashier],
        companyId: 'company_tatuzin',
      ),
      tokens: AuthTokenPair(
        accessToken: '',
        refreshToken: '',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
      ),
      companyContext: const CompanyContext(
        companyId: 'company_tatuzin',
        companyName: 'Tatuzin Moda',
      ),
      deviceRegistration: DeviceRegistration(
        deviceId: 'device_sync_regression',
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
    session = session.copyWith(tokens: await _loginAsCashier(backendApiClient));
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
    'syncs a full offline note sale and keeps sale plus receivable note idempotent on retry',
    () async {
      final dueDate = DateTime.utc(2026, 5, 30);
      final variants = await catalogDatasource.searchVariants(query: 'Bolsa');
      final cart = Cart(
        items: <CartItem>[CartItem(variant: variants.single, quantity: 1)],
      );

      final checkoutResult = await checkoutDatasource.completeCheckout(
        request: CheckoutRequest(
          cart: cart,
          paymentMethod: PaymentMethod.note,
          amountReceivedInCents: 0,
          pixConfirmedManually: false,
          noteDueDate: dueDate,
          customerName: 'Maria Sync',
          customerPhone: '(11) 99999-0000',
          noteDescription: 'Parcela unica',
        ),
        session: session,
      );

      final db = await database.database;
      final quickCustomers = await db.query('quick_customers');
      final sales = await db.query('sales');
      final payments = await db.query('payments');
      final paymentTerms = await db.query('payment_terms');
      final receipts = await db.query('receipts');
      final cashMovements = await db.query(
        'cash_movements',
        orderBy: 'created_at ASC',
      );
      final outboxRows = await db.query(
        'sync_outbox',
        orderBy: 'created_at ASC',
      );
      final pendingOperations = await outboxDatasource
          .loadOperationsForProcessing(limit: 20);

      expect(checkoutResult.quickCustomer, isNotNull);
      expect(checkoutResult.paymentTerm, isNotNull);
      expect(checkoutResult.payment.amountInCents, cart.totalInCents);
      expect(quickCustomers, hasLength(1));
      expect(sales, hasLength(1));
      expect(payments, hasLength(1));
      expect(paymentTerms, hasLength(1));
      expect(receipts, hasLength(1));
      expect(cashMovements, hasLength(2));
      expect(outboxRows, hasLength(5));
      expect(
        outboxRows.map((row) => row['type']),
        containsAll(<Object?>[
          'quick_customer',
          'sale',
          'cash_movement',
          'receivable_note',
        ]),
      );
      expect(
        outboxRows.every(
          (row) => row['status'] == SyncRecordStatus.pending.wireValue,
        ),
        isTrue,
      );
      expect(
        pendingOperations.map((operation) => operation.type.wireValue).toList(),
        <String>[
          'quick_customer',
          'sale',
          'cash_movement',
          'cash_movement',
          'receivable_note',
        ],
      );
      expect(
        pendingOperations.where(
          (operation) => operation.type == SyncOperationType.cashMovement,
        ),
        hasLength(2),
      );

      final quickCustomer = quickCustomers.single;
      final sale = sales.single;
      final payment = payments.single;
      final paymentTerm = paymentTerms.single;
      final receipt = receipts.single;

      expect(quickCustomer['remote_id'], isNull);
      expect(quickCustomer['name'], 'Maria Sync');
      expect(quickCustomer['phone'], '11999990000');
      expect(quickCustomer['sync_status'], SyncRecordStatus.pending.wireValue);
      expect(sale['customer_local_id'], quickCustomer['local_id']);
      expect(sale['remote_id'], isNull);
      expect(sale['synced_at'], isNull);
      expect(payment['sale_local_id'], sale['local_id']);
      expect(payment['method'], PaymentMethod.note.wireValue);
      expect(payment['status'], 'pending');
      expect(payment['amount_cents'], cart.totalInCents);
      expect(paymentTerm['sale_local_id'], sale['local_id']);
      expect(paymentTerm['customer_local_id'], quickCustomer['local_id']);
      expect(paymentTerm['remote_id'], isNull);
      expect(paymentTerm['due_date'], dueDate.toIso8601String());
      expect(
        paymentTerm['outstanding_amount_cents'],
        checkoutResult.paymentTerm!.outstandingAmountInCents,
      );
      expect(paymentTerm['sync_status'], SyncRecordStatus.pending.wireValue);
      expect(receipt['sale_local_id'], sale['local_id']);
      expect(receipt['pdf_path'], checkoutResult.receipt.pdfPath);
      expect(File(checkoutResult.receipt.pdfPath).existsSync(), isTrue);
      expect(cashMovements.map((row) => row['type']).toList(), <String>[
        CashMovementType.opening.wireValue,
        CashMovementType.saleNote.wireValue,
      ]);

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

      final syncedQuickCustomers = await db.query('quick_customers');
      final syncedSales = await db.query('sales');
      final syncedPaymentTerms = await db.query('payment_terms');
      final syncedCashMovements = await db.query(
        'cash_movements',
        orderBy: 'created_at ASC',
      );
      final syncedOutbox = await db.query(
        'sync_outbox',
        orderBy: 'created_at ASC',
      );
      final syncedCategories = await db.query(
        'categories_snapshot',
        where: 'remote_id = ?',
        whereArgs: <Object>['cat_basicos'],
      );
      final cursor = await inboxDatasource.loadCursor();
      final snapshot = await outboxDatasource.loadStatusSnapshot();

      expect(summary.processedOperations, pendingOperations.length);
      expect(summary.syncedOperations, pendingOperations.length);
      expect(summary.failedOperations, 0);
      expect(summary.conflictOperations, 0);
      expect(summary.receivedUpdates, 4);
      expect(summary.appliedUpdates, 4);
      expect(snapshot.pendingOperations, 0);
      expect(snapshot.failedOperations, 0);
      expect(syncedCategories.single['name'], 'Basicos');
      expect(cursor, '0004');
      expect(
        syncedOutbox.every(
          (row) => row['status'] == SyncRecordStatus.synced.wireValue,
        ),
        isTrue,
      );
      expect(syncedQuickCustomers.single['remote_id'], isNotNull);
      expect(
        syncedQuickCustomers.single['sync_status'],
        SyncRecordStatus.synced.wireValue,
      );
      expect(syncedSales.single['remote_id'], isNotNull);
      expect(syncedSales.single['synced_at'], isNotNull);
      expect(syncedPaymentTerms.single['remote_id'], isNotNull);
      expect(
        syncedPaymentTerms.single['sync_status'],
        SyncRecordStatus.synced.wireValue,
      );
      expect(
        syncedCashMovements.every((row) => row['remote_id'] != null),
        isTrue,
      );
      expect(
        syncedCashMovements.every(
          (row) => row['sync_status'] == SyncRecordStatus.synced.wireValue,
        ),
        isTrue,
      );

      final backendSalesBeforeRetry = _asMapList(
        _asMap(
          await backendApiClient.getJson(
            path: '/api/sales',
            bearerToken: session.tokens.accessToken,
          ),
        )['items'],
      );
      final backendNotesBeforeRetry = _asMapList(
        _asMap(
          await backendApiClient.getJson(
            path: '/api/receivables',
            bearerToken: session.tokens.accessToken,
          ),
        )['items'],
      );

      expect(backendSalesBeforeRetry, hasLength(1));
      expect(backendNotesBeforeRetry, hasLength(1));

      final backendSale = backendSalesBeforeRetry.single;
      final backendSalePayments = _asMapList(backendSale['payments']);
      final backendNote = backendNotesBeforeRetry.single;

      expect(
        backendSale['customerId'],
        syncedQuickCustomers.single['remote_id'],
      );
      expect(backendSale['totalInCents'], cart.totalInCents);
      expect(backendSale['status'], 'completed');
      expect(backendSalePayments, hasLength(1));
      expect(
        backendSalePayments.single['method'],
        PaymentMethod.note.wireValue,
      );
      expect(backendSalePayments.single['amountInCents'], cart.totalInCents);
      expect(backendSalePayments.single['dueDate'], dueDate.toIso8601String());
      expect(backendNote['saleId'], backendSale['id']);
      expect(backendNote['customerId'], backendSale['customerId']);
      expect(backendNote['originalAmountInCents'], cart.totalInCents);
      expect(backendNote['outstandingAmountInCents'], cart.totalInCents);
      expect(backendNote['dueDate'], dueDate.toIso8601String());
      expect(backendNote['status'], 'pending');

      final retryResults = await remoteDatasource.sendOutbox(
        session: session,
        operations: pendingOperations,
      );

      expect(retryResults, hasLength(pendingOperations.length));
      expect(
        retryResults
            .singleWhere((result) => result.type == 'quick_customer')
            .status,
        'idempotent',
      );
      expect(
        retryResults.singleWhere((result) => result.type == 'sale').status,
        'idempotent',
      );
      expect(
        retryResults
            .singleWhere((result) => result.type == 'receivable_note')
            .status,
        'idempotent',
      );

      final backendSalesAfterRetry = _asMapList(
        _asMap(
          await backendApiClient.getJson(
            path: '/api/sales',
            bearerToken: session.tokens.accessToken,
          ),
        )['items'],
      );
      final backendNotesAfterRetry = _asMapList(
        _asMap(
          await backendApiClient.getJson(
            path: '/api/receivables',
            bearerToken: session.tokens.accessToken,
          ),
        )['items'],
      );

      expect(backendSalesAfterRetry, hasLength(1));
      expect(backendNotesAfterRetry, hasLength(1));
      expect(backendSalesAfterRetry.single['id'], backendSale['id']);
      expect(backendNotesAfterRetry.single['id'], backendNote['id']);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<AuthTokenPair> _loginAsCashier(ApiClient apiClient) async {
  final response = _asMap(
    await apiClient.postJson(
      path: '/api/auth/login',
      body: const <String, Object?>{
        'email': 'cashier@tatuzin.app',
        'password': 'tatuzin123',
      },
    ),
  );
  final tokens = _asMap(response['tokens']);
  return AuthTokenPair(
    accessToken: tokens['accessToken']! as String,
    refreshToken: tokens['refreshToken']! as String,
    expiresAt: DateTime.parse(tokens['expiresAt']! as String),
  );
}

Map<String, dynamic> _asMap(dynamic value) {
  return (value as Map).cast<String, dynamic>();
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  return (value as List<dynamic>).map(_asMap).toList();
}

class _BackendHarness {
  _BackendHarness({
    required this.process,
    required this.baseUrl,
    required this.stdoutBuffer,
    required this.stderrBuffer,
  });

  final Process process;
  final String baseUrl;
  final StringBuffer stdoutBuffer;
  final StringBuffer stderrBuffer;

  static Future<_BackendHarness> start() async {
    final port = await _pickAvailablePort();
    final backendDir = Directory(p.join(Directory.current.path, 'backend'));
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final process = await Process.start(
      Platform.isWindows ? 'cmd.exe' : 'sh',
      Platform.isWindows
          ? <String>[
              '/c',
              p.join('node_modules', '.bin', 'tsx.cmd'),
              'src/index.ts',
            ]
          : <String>['-c', './node_modules/.bin/tsx src/index.ts'],
      workingDirectory: backendDir.path,
      environment: <String, String>{
        ...Platform.environment,
        'PORT': '$port',
        'TATUZIN_PERSISTENCE': 'memory',
      },
    );

    process.stdout
        .transform(utf8.decoder)
        .listen((chunk) => stdoutBuffer.write(chunk));
    process.stderr
        .transform(utf8.decoder)
        .listen((chunk) => stderrBuffer.write(chunk));

    final harness = _BackendHarness(
      process: process,
      baseUrl: 'http://127.0.0.1:$port',
      stdoutBuffer: stdoutBuffer,
      stderrBuffer: stderrBuffer,
    );
    await harness._waitUntilReady();
    return harness;
  }

  Future<void> stop() async {
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }

  Future<void> _waitUntilReady() async {
    final client = _createRealHttpClient();
    final deadline = DateTime.now().add(const Duration(seconds: 25));

    try {
      while (DateTime.now().isBefore(deadline)) {
        final exitCode = await _tryReadExitCode();
        if (exitCode != null) {
          break;
        }

        try {
          final request = await client.getUrl(Uri.parse('$baseUrl/health'));
          final response = await request.close().timeout(
            const Duration(seconds: 2),
          );
          if (response.statusCode == 200) {
            await response.drain<void>();
            return;
          }
          await response.drain<void>();
        } on Object {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    } finally {
      client.close(force: true);
    }

    final exitCode = await _tryReadExitCode();
    throw TestFailure(
      'Backend test server did not become ready at $baseUrl.\n'
      'Exit code: ${exitCode ?? 'still running'}\n'
      'STDOUT:\n$stdoutBuffer\n'
      'STDERR:\n$stderrBuffer',
    );
  }

  Future<int?> _tryReadExitCode() {
    return Future.any<int?>(<Future<int?>>[
      process.exitCode.then<int?>((value) => value),
      Future<int?>.delayed(const Duration(milliseconds: 1), () => null),
    ]);
  }

  static Future<int> _pickAvailablePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }
}

HttpClient _createRealHttpClient() {
  late HttpClient client;
  HttpOverrides.runWithHttpOverrides(() {
    client = HttpClient();
  }, _RealHttpOverrides());
  return client;
}

class _RealHttpOverrides extends HttpOverrides {
}
