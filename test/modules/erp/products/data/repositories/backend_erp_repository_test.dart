import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/core/networking/api_client.dart';
import 'package:tatuzin/modules/erp/products/data/datasources/remote/erp_remote_datasource.dart';
import 'package:tatuzin/modules/erp/products/data/repositories/backend_erp_repository.dart';
import 'package:tatuzin/modules/erp/products/domain/repositories/erp_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'erp-repository-test-${DateTime.now().microsecondsSinceEpoch}.db',
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

  test('loads ERP overview including receivables and cash sessions', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token_erp');

      switch (request.url.path) {
        case '/api/catalog/categories':
          return _itemsResponse(<Map<String, dynamic>>[_categoryJson()]);
        case '/api/catalog/products':
          return _itemsResponse(<Map<String, dynamic>>[_productJson()]);
        case '/api/catalog/variants':
          return _itemsResponse(<Map<String, dynamic>>[_variantJson()]);
        case '/api/inventory/summary':
          return _itemsResponse(<Map<String, dynamic>>[_inventoryJson()]);
        case '/api/suppliers':
          return _itemsResponse(<Map<String, dynamic>>[_supplierJson()]);
        case '/api/purchases':
          return _itemsResponse(<Map<String, dynamic>>[_purchaseJson()]);
        case '/api/receivables':
          return _itemsResponse(<Map<String, dynamic>>[_receivableJson()]);
        case '/api/cash/sessions':
          return _itemsResponse(<Map<String, dynamic>>[_cashSessionJson()]);
        default:
          fail('Endpoint inesperado: ${request.url.path}');
      }
    });

    final repository = _createRepository(database, client);
    final overview = await repository.loadOverview(accessToken: 'token_erp');

    expect(overview.categories.single.name, 'Basicos');
    expect(overview.inventoryItems.single.quantityOnHand, 12);
    expect(overview.receivables.single.outstandingAmountInCents, 7000);
    expect(overview.outstandingReceivablesInCents, 7000);
    expect(overview.cashSessions.single.expectedCashBalanceInCents, 18000);
    expect(overview.openCashSessionCount, 1);
  });

  test(
    'posts inventory adjustments, counts and receivable settlements',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer token_erp');

        switch ('${request.method} ${request.url.path}') {
          case 'POST /api/inventory/adjustments':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['variantId'], 'variant_001');
            expect(body['quantityDelta'], -2);
            return _jsonResponse(_inventoryJson(quantityOnHand: 10));
          case 'POST /api/inventory/counts':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect((body['items'] as List<dynamic>).single, <String, dynamic>{
              'variantId': 'variant_001',
              'countedQuantity': 9,
            });
            return _itemsResponse(<Map<String, dynamic>>[
              _inventoryJson(quantityOnHand: 9),
            ]);
          case 'POST /api/receivables/note_001/settlements':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['amountInCents'], 3000);
            expect(body['settlementMethod'], 'pix');
            expect(body['operationId'], startsWith('app-settlement-'));
            return _jsonResponse(<String, dynamic>{
              'duplicated': false,
              'note': _receivableJson(outstandingAmountInCents: 4000),
              'settlement': <String, dynamic>{'id': 'settlement_001'},
            }, statusCode: 201);
          default:
            fail(
              'Requisicao inesperada: ${request.method} ${request.url.path}',
            );
        }
      });

      final repository = _createRepository(database, client);
      await repository.createInventoryAdjustment(
        accessToken: 'token_erp',
        variantId: 'variant_001',
        quantityDelta: -2,
        reason: 'cycle_count',
      );
      await repository.recordInventoryCount(
        accessToken: 'token_erp',
        items: const <ErpInventoryCountDraftItem>[
          ErpInventoryCountDraftItem(
            variantId: 'variant_001',
            countedQuantity: 9,
          ),
        ],
      );
      await repository.settleReceivable(
        accessToken: 'token_erp',
        receivableId: 'note_001',
        amountInCents: 3000,
        settlementMethod: 'pix',
      );

      expect(requests, hasLength(3));
    },
  );

  test('loads reports dashboard from the backend payload', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token_erp');
      expect(request.url.path, '/api/reports/dashboard');

      return _jsonResponse(_reportsJson());
    });

    final repository = _createRepository(database, client);
    final dashboard = await repository.loadReportsDashboard(
      accessToken: 'token_erp',
    );

    expect(dashboard.daily.salesCount, 4);
    expect(dashboard.weekly.netRevenueInCents, 78500);
    expect(dashboard.monthly.topProducts.single.label, 'Bolsa Tiracolo');
    expect(dashboard.monthly.paymentBreakdown.single.amountInCents, 78500);
  });
}

BackendErpRepository _createRepository(
  AppDatabase database,
  http.Client client,
) {
  final apiClient = ApiClient(
    database: database,
    logger: const AppLogger(),
    httpClient: client,
    defaultBaseUrl: 'http://erp.test',
  );

  return BackendErpRepository(
    remoteDatasource: ErpRemoteDatasource(apiClient: apiClient),
  );
}

http.Response _itemsResponse(List<Map<String, dynamic>> items) {
  return _jsonResponse(<String, dynamic>{'items': items});
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

Map<String, dynamic> _categoryJson() {
  return <String, dynamic>{
    'id': 'cat_001',
    'name': 'Basicos',
    'active': true,
    'createdAt': '2026-04-21T09:00:00.000Z',
    'updatedAt': '2026-04-21T09:00:00.000Z',
  };
}

Map<String, dynamic> _productJson() {
  return <String, dynamic>{
    'id': 'product_001',
    'name': 'Camiseta',
    'categoryId': 'cat_001',
    'categoryName': 'Basicos',
    'active': true,
    'createdAt': '2026-04-21T09:01:00.000Z',
    'updatedAt': '2026-04-21T09:01:00.000Z',
  };
}

Map<String, dynamic> _variantJson() {
  return <String, dynamic>{
    'id': 'variant_001',
    'productId': 'product_001',
    'productName': 'Camiseta',
    'displayName': 'Camiseta Preta M',
    'shortName': 'Preta M',
    'barcode': '7891000000011',
    'sku': 'CAM-PRT-M',
    'color': 'Preta',
    'size': 'M',
    'priceInCents': 9900,
    'active': true,
    'createdAt': '2026-04-21T09:02:00.000Z',
    'updatedAt': '2026-04-21T09:02:00.000Z',
  };
}

Map<String, dynamic> _inventoryJson({int quantityOnHand = 12}) {
  return <String, dynamic>{
    'companyId': 'company_tatuzin',
    'variantId': 'variant_001',
    'productId': 'product_001',
    'productName': 'Camiseta',
    'variantDisplayName': 'Camiseta Preta M',
    'quantityOnHand': quantityOnHand,
    'sku': 'CAM-PRT-M',
    'barcode': '7891000000011',
    'color': 'Preta',
    'size': 'M',
    'updatedAt': '2026-04-21T09:15:00.000Z',
  };
}

Map<String, dynamic> _supplierJson() {
  return <String, dynamic>{
    'id': 'supplier_001',
    'name': 'Fornecedor Sul',
    'phone': '11999990000',
    'email': 'sul@fornecedor.app',
    'notes': 'Fornecedor teste',
    'createdAt': '2026-04-21T09:20:00.000Z',
    'updatedAt': '2026-04-21T09:20:00.000Z',
  };
}

Map<String, dynamic> _purchaseJson() {
  return <String, dynamic>{
    'id': 'purchase_001',
    'supplierId': 'supplier_001',
    'supplierName': 'Fornecedor Sul',
    'status': 'pending',
    'notes': 'Reposicao',
    'createdAt': '2026-04-21T09:25:00.000Z',
    'updatedAt': '2026-04-21T09:25:00.000Z',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'purchase_item_001',
        'variantId': 'variant_001',
        'variantDisplayName': 'Camiseta Preta M',
        'quantityOrdered': 5,
        'quantityReceived': 0,
        'unitCostInCents': 5000,
        'lineTotalInCents': 25000,
      },
    ],
    'receipts': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _receivableJson({int outstandingAmountInCents = 7000}) {
  return <String, dynamic>{
    'id': 'note_001',
    'saleId': 'sale_001',
    'customerId': 'customer_001',
    'originalAmountInCents': 12000,
    'paidAmountInCents': 5000,
    'outstandingAmountInCents': outstandingAmountInCents,
    'dueDate': '2026-05-22T00:00:00.000Z',
    'issueDate': '2026-04-22T08:00:00.000Z',
    'status': outstandingAmountInCents == 0 ? 'paid' : 'partially_paid',
  };
}

Map<String, dynamic> _cashSessionJson() {
  return <String, dynamic>{
    'cashSessionLocalId': 'cash_session_001',
    'status': 'open',
    'openedAt': '2026-04-22T08:00:00.000Z',
    'updatedAt': '2026-04-22T11:00:00.000Z',
    'openingAmountInCents': 10000,
    'cashSalesInCents': 8000,
    'pixSalesInCents': 3000,
    'noteSalesInCents': 12000,
    'suppliesInCents': 0,
    'withdrawalsInCents': 0,
    'receivableSettlementCashInCents': 0,
    'receivableSettlementPixInCents': 2000,
    'expectedCashBalanceInCents': 18000,
    'movementCount': 4,
  };
}

Map<String, dynamic> _reportsJson() {
  final daily = <String, dynamic>{
    'period': 'daily',
    'label': 'Diario',
    'startsAt': '2026-04-21T00:00:00.000Z',
    'endsAt': '2026-04-22T00:00:00.000Z',
    'salesCount': 4,
    'itemsSold': 7,
    'grossRevenueInCents': 80000,
    'discountInCents': 1500,
    'netRevenueInCents': 78500,
    'averageTicketInCents': 19625,
    'liquidatedRevenueInCents': 78500,
    'noteRevenueInCents': 0,
    'openReceivablesInCents': 12000,
    'overdueReceivablesInCents': 0,
    'openReceivablesCount': 1,
    'overdueReceivablesCount': 0,
    'paymentBreakdown': <Map<String, dynamic>>[
      <String, dynamic>{
        'method': 'cash',
        'amountInCents': 78500,
        'transactionCount': 4,
      },
    ],
    'topProducts': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'prod_bolsa_tiracolo',
        'label': 'Bolsa Tiracolo',
        'unitsSold': 3,
        'revenueInCents': 45000,
        'salesCount': 2,
      },
    ],
    'topVariants': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'var_bolsa_tiracolo_preta_u',
        'label': 'Bolsa Tiracolo Preta U',
        'unitsSold': 3,
        'revenueInCents': 45000,
        'salesCount': 2,
      },
    ],
  };

  return <String, dynamic>{
    'generatedAt': '2026-04-21T12:10:00.000Z',
    'referenceDate': '2026-04-21T12:00:00.000Z',
    'reports': <String, dynamic>{
      'daily': daily,
      'weekly': daily,
      'monthly': daily,
    },
  };
}
