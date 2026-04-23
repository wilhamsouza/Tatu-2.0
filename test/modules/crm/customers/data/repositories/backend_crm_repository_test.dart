import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/core/networking/api_client.dart';
import 'package:tatuzin/modules/crm/customers/data/datasources/remote/crm_remote_datasource.dart';
import 'package:tatuzin/modules/crm/customers/data/repositories/backend_crm_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'crm-repository-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();
  });

  tearDown(() async {
    final path = await database.database.then((db) => db.path);
    await database.close();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('lists customers and loads customer detail payloads', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token_crm');

      switch (request.url.path) {
        case '/api/customers':
          expect(request.url.queryParameters['query'], 'maria');
          return _jsonResponse(<String, dynamic>{
            'items': <Map<String, dynamic>>[_customerJson()],
          });
        case '/api/customers/customer_001/summary':
          return _jsonResponse(_summaryJson());
        case '/api/customers/customer_001/history':
          return _jsonResponse(_historyJson());
        default:
          fail('Endpoint inesperado: ${request.url.path}');
      }
    });

    final repository = _createRepository(database, client);

    final customers = await repository.listCustomers(
      accessToken: 'token_crm',
      query: 'maria',
    );
    final summary = await repository.loadCustomerSummary(
      accessToken: 'token_crm',
      customerId: 'customer_001',
    );
    final history = await repository.loadCustomerHistory(
      accessToken: 'token_crm',
      customerId: 'customer_001',
    );

    expect(customers.single.name, 'Maria CRM');
    expect(customers.single.totalPurchases, 3);
    expect(summary.totalOutstandingInCents, 12000);
    expect(summary.receivables.single.status, 'pending');
    expect(history.purchases.single.paymentMethods, <String>['note']);
    expect(history.purchases.single.items.single.displayName, 'Vestido Midi');
  });

  test('creates and updates customers with the expected payload', () async {
    final requests = <http.Request>[];

    final client = MockClient((request) async {
      requests.add(request);

      switch ('${request.method} ${request.url.path}') {
        case 'POST /api/customers':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'Maria CRM');
          expect(body['phone'], '(11) 97777-6600');
          return _jsonResponse(_customerJson(), statusCode: 201);
        case 'PUT /api/customers/customer_001':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'Maria CRM Atualizada');
          expect(body['notes'], 'Cliente premium');
          return _jsonResponse(
            _customerJson(
              name: 'Maria CRM Atualizada',
              notes: 'Cliente premium',
            ),
          );
        default:
          fail('Requisicao inesperada: ${request.method} ${request.url.path}');
      }
    });

    final repository = _createRepository(database, client);

    final created = await repository.createCustomer(
      accessToken: 'token_crm',
      name: 'Maria CRM',
      phone: '(11) 97777-6600',
      email: 'maria@crm.app',
    );
    final updated = await repository.updateCustomer(
      accessToken: 'token_crm',
      customerId: 'customer_001',
      name: 'Maria CRM Atualizada',
      notes: 'Cliente premium',
    );

    expect(created.id, 'customer_001');
    expect(updated.name, 'Maria CRM Atualizada');
    expect(requests, hasLength(2));
  });

  test('exports the current CRM segment as CSV text', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token_crm');
      expect(request.url.path, '/api/crm/segments/export');
      expect(request.url.queryParameters['format'], 'csv');
      expect(request.url.queryParameters['query'], 'maria');

      return http.Response(
        'id,name,phone,email\ncustomer_001,Maria CRM,11977776600,maria@crm.app',
        200,
        headers: const <String, String>{'content-type': 'text/csv'},
      );
    });

    final repository = _createRepository(database, client);
    final csv = await repository.exportSegmentCsv(
      accessToken: 'token_crm',
      query: 'maria',
    );

    expect(csv, contains('id,name,phone,email'));
    expect(csv, contains('Maria CRM'));
  });
}

BackendCrmRepository _createRepository(
  AppDatabase database,
  http.Client client,
) {
  final apiClient = ApiClient(
    database: database,
    logger: const AppLogger(),
    httpClient: client,
    defaultBaseUrl: 'http://crm.test',
  );

  return BackendCrmRepository(
    remoteDatasource: CrmRemoteDatasource(apiClient: apiClient),
  );
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

Map<String, dynamic> _customerJson({
  String name = 'Maria CRM',
  String? notes = 'Cliente de nota',
}) {
  return <String, dynamic>{
    'id': 'customer_001',
    'name': name,
    'phone': '11977776600',
    'email': 'maria@crm.app',
    'address': 'Rua A, 123',
    'notes': notes,
    'createdAt': '2026-04-21T09:00:00.000Z',
    'updatedAt': '2026-04-21T10:00:00.000Z',
    'source': 'manual',
    'totalPurchases': 3,
    'totalSpentInCents': 45000,
    'lastPurchaseAt': '2026-04-21T10:05:00.000Z',
    'totalOutstandingInCents': 12000,
    'openReceivablesCount': 1,
    'overdueReceivablesCount': 0,
  };
}

Map<String, dynamic> _summaryJson() {
  return <String, dynamic>{
    'customer': _customerJson(),
    'totalPurchases': 3,
    'totalSpentInCents': 45000,
    'averageTicketInCents': 15000,
    'lastPurchaseAt': '2026-04-21T10:05:00.000Z',
    'totalOutstandingInCents': 12000,
    'openReceivablesCount': 1,
    'overdueReceivablesCount': 0,
    'receivables': <Map<String, dynamic>>[
      <String, dynamic>{
        'noteId': 'note_001',
        'saleId': 'sale_001',
        'originalAmountInCents': 12000,
        'paidAmountInCents': 0,
        'outstandingAmountInCents': 12000,
        'dueDate': '2026-05-25T00:00:00.000Z',
        'issueDate': '2026-04-21T10:05:00.000Z',
        'status': 'pending',
      },
    ],
  };
}

Map<String, dynamic> _historyJson() {
  return <String, dynamic>{
    'customer': _customerJson(),
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'saleId': 'sale_001',
        'createdAt': '2026-04-21T10:05:00.000Z',
        'subtotalInCents': 15000,
        'discountInCents': 0,
        'totalInCents': 15000,
        'itemCount': 1,
        'paymentMethods': <String>['note'],
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'displayName': 'Vestido Midi',
            'quantity': 1,
            'unitPriceInCents': 15000,
            'totalPriceInCents': 15000,
          },
        ],
        'outstandingAmountInCents': 12000,
        'receivableStatus': 'pending',
        'receivableDueDate': '2026-05-25T00:00:00.000Z',
      },
    ],
  };
}
