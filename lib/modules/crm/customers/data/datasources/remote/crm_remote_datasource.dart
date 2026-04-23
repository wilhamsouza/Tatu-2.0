import '../../../../../../core/networking/api_client.dart';

class CrmRemoteDatasource {
  const CrmRemoteDatasource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> listCustomers({
    required String accessToken,
    String? query,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/customers',
      queryParameters: query == null || query.trim().isEmpty
          ? null
          : <String, String>{'query': query.trim()},
      bearerToken: accessToken,
    );
    return _readItems(response, key: 'items');
  }

  Future<Map<String, dynamic>> createCustomer({
    required String accessToken,
    required String name,
    required String phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final response = await _apiClient.postJson(
      path: '/api/customers',
      bearerToken: accessToken,
      body: _compact(<String, dynamic>{
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
      }),
    );
    return _readObject(response);
  }

  Future<Map<String, dynamic>> updateCustomer({
    required String accessToken,
    required String customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'address': address,
      'notes': notes,
    };
    if (name != null) {
      body['name'] = name;
    }
    if (phone != null) {
      body['phone'] = phone;
    }

    final response = await _apiClient.putJson(
      path: '/api/customers/$customerId',
      bearerToken: accessToken,
      body: body,
    );
    return _readObject(response);
  }

  Future<Map<String, dynamic>> fetchCustomerHistory({
    required String accessToken,
    required String customerId,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/customers/$customerId/history',
      bearerToken: accessToken,
    );
    return _readObject(response);
  }

  Future<Map<String, dynamic>> fetchCustomerSummary({
    required String accessToken,
    required String customerId,
  }) async {
    final response = await _apiClient.getJson(
      path: '/api/customers/$customerId/summary',
      bearerToken: accessToken,
    );
    return _readObject(response);
  }

  Future<String> exportSegmentCsv({
    required String accessToken,
    String? query,
  }) {
    return _apiClient.getText(
      path: '/api/crm/segments/export',
      queryParameters: <String, String>{
        'format': 'csv',
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      },
      bearerToken: accessToken,
    );
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
