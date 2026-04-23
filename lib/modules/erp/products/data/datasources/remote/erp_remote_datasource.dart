import '../../../../../../core/networking/api_client.dart';

class ErpRemoteDatasource {
  const ErpRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchCategories({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/catalog/categories',
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> createCategory({
    required String accessToken,
    required String name,
    required bool active,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/catalog/categories',
      bearerToken: accessToken,
      body: <String, dynamic>{'name': name, 'active': active},
    );
    return _readObject(response);
  }

  Future<Map<String, dynamic>> updateCategory({
    required String accessToken,
    required String categoryId,
    String? name,
    bool? active,
  }) async {
    final response = await _apiClient.putJson(
      path: '/api/catalog/categories/$categoryId',
      bearerToken: accessToken,
      body: _compact(<String, dynamic>{'name': name, 'active': active}),
    );
    return _readObject(response);
  }

  Future<List<Map<String, dynamic>>> fetchProducts({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/catalog/products',
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> createProduct({
    required String accessToken,
    required String name,
    String? categoryId,
    required bool active,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/catalog/products',
      bearerToken: accessToken,
      body: _compact(<String, dynamic>{
        'name': name,
        'categoryId': categoryId,
        'active': active,
      }),
    );
    return _readObject(response);
  }

  Future<Map<String, dynamic>> updateProduct({
    required String accessToken,
    required String productId,
    String? name,
    String? categoryId,
    bool? active,
  }) async {
    final body = <String, dynamic>{'categoryId': categoryId};
    if (name != null) {
      body['name'] = name;
    }
    if (active != null) {
      body['active'] = active;
    }

    final response = await _apiClient.putJson(
      path: '/api/catalog/products/$productId',
      bearerToken: accessToken,
      body: body,
    );
    return _readObject(response);
  }

  Future<List<Map<String, dynamic>>> fetchVariants({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/catalog/variants',
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> createVariant({
    required String accessToken,
    required String productId,
    String? barcode,
    String? sku,
    String? color,
    String? size,
    required int priceInCents,
    int? promotionalPriceInCents,
    required bool active,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/catalog/variants',
      bearerToken: accessToken,
      body: _compact(<String, dynamic>{
        'productId': productId,
        'barcode': barcode,
        'sku': sku,
        'color': color,
        'size': size,
        'priceInCents': priceInCents,
        'promotionalPriceInCents': promotionalPriceInCents,
        'active': active,
      }),
    );
    return _readObject(response);
  }

  Future<Map<String, dynamic>> updateVariant({
    required String accessToken,
    required String variantId,
    String? barcode,
    String? sku,
    String? color,
    String? size,
    int? priceInCents,
    int? promotionalPriceInCents,
    bool? active,
  }) async {
    final body = <String, dynamic>{
      'barcode': barcode,
      'sku': sku,
      'color': color,
      'size': size,
      'promotionalPriceInCents': promotionalPriceInCents,
    };
    if (priceInCents != null) {
      body['priceInCents'] = priceInCents;
    }
    if (active != null) {
      body['active'] = active;
    }

    final response = await _apiClient.putJson(
      path: '/api/catalog/variants/$variantId',
      bearerToken: accessToken,
      body: body,
    );
    return _readObject(response);
  }

  Future<List<Map<String, dynamic>>> fetchInventorySummary({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/inventory/summary',
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> createInventoryAdjustment({
    required String accessToken,
    required String variantId,
    required int quantityDelta,
    String? reason,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/inventory/adjustments',
      bearerToken: accessToken,
      body: _compact(<String, dynamic>{
        'variantId': variantId,
        'quantityDelta': quantityDelta,
        'reason': reason,
      }),
    );
    return _readObject(response);
  }

  Future<List<Map<String, dynamic>>> recordInventoryCount({
    required String accessToken,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/inventory/counts',
      bearerToken: accessToken,
      body: <String, dynamic>{'items': items},
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> fetchReportsDashboard({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/reports/dashboard',
      bearerToken: accessToken,
    );
    return _readObject(response);
  }

  Future<List<Map<String, dynamic>>> fetchReceivables({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/receivables',
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> settleReceivable({
    required String accessToken,
    required String receivableId,
    required int amountInCents,
    required String settlementMethod,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/receivables/$receivableId/settlements',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'operationId':
            'app-settlement-${DateTime.now().microsecondsSinceEpoch}',
        'amountInCents': amountInCents,
        'settlementMethod': settlementMethod,
      },
    );
    return _readObject(response);
  }

  Future<List<Map<String, dynamic>>> fetchCashSessions({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/cash/sessions',
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<List<Map<String, dynamic>>> fetchSuppliers({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/suppliers',
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> createSupplier({
    required String accessToken,
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/suppliers',
      bearerToken: accessToken,
      body: _compact(<String, dynamic>{
        'name': name,
        'phone': phone,
        'email': email,
        'notes': notes,
      }),
    );
    return _readObject(response);
  }

  Future<List<Map<String, dynamic>>> fetchPurchases({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/purchases',
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> createPurchase({
    required String accessToken,
    required String supplierId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/purchases',
      bearerToken: accessToken,
      body: _compact(<String, dynamic>{
        'supplierId': supplierId,
        'notes': notes,
        'items': items,
      }),
    );
    return _readObject(response);
  }

  Future<Map<String, dynamic>> receivePurchase({
    required String accessToken,
    required String purchaseId,
    String? receivedAtIso,
    required List<Map<String, dynamic>> items,
  }) async {
    final body = <String, dynamic>{'items': items};
    if (receivedAtIso != null) {
      body['receivedAt'] = receivedAtIso;
    }

    final response = await _apiClient.postJson(
      path: '/api/purchases/$purchaseId/receive',
      bearerToken: accessToken,
      body: body,
    );
    return _readObject(response);
  }
}

List<Map<String, dynamic>> _readItems(dynamic value, {required String key}) {
  final map = _readObject(value);
  return (map[key] as List<dynamic>? ?? const <dynamic>[])
      .map((item) => (item as Map).cast<String, dynamic>())
      .toList();
}

Map<String, dynamic> _readObject(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.cast<String, dynamic>();
  }

  throw const ApiException('Resposta invalida recebida do backend Tatuzin.');
}

Map<String, dynamic> _compact(Map<String, dynamic> value) {
  final result = <String, dynamic>{};
  value.forEach((key, currentValue) {
    if (currentValue == null) {
      return;
    }
    if (currentValue is String && currentValue.trim().isEmpty) {
      return;
    }
    result[key] = currentValue;
  });
  return result;
}
