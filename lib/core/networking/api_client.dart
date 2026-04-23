import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import '../logging/app_logger.dart';

class ApiClient {
  ApiClient({
    required AppDatabase database,
    required AppLogger logger,
    http.Client? httpClient,
    String? defaultBaseUrl,
  }) : _database = database,
       _logger = logger,
       _httpClient = httpClient ?? http.Client(),
       _defaultBaseUrl = defaultBaseUrl;

  static const String apiBaseUrlSettingKey = 'network.api_base_url';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'TATUZIN_API_BASE_URL',
  );
  static const String _releaseBaseUrl = String.fromEnvironment(
    'TATUZIN_PRODUCTION_API_BASE_URL',
    defaultValue: 'https://api.tatuzin.com.br',
  );

  final AppDatabase _database;
  final AppLogger _logger;
  final http.Client _httpClient;
  final String? _defaultBaseUrl;

  Future<dynamic> getJson({
    required String path,
    Map<String, String>? queryParameters,
    String? bearerToken,
  }) {
    return _send(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      bearerToken: bearerToken,
    );
  }

  Future<String> getText({
    required String path,
    Map<String, String>? queryParameters,
    String? bearerToken,
  }) {
    return _sendText(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      bearerToken: bearerToken,
    );
  }

  Future<dynamic> postJson({
    required String path,
    Object? body,
    String? bearerToken,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      bearerToken: bearerToken,
    );
  }

  Future<dynamic> putJson({
    required String path,
    Object? body,
    String? bearerToken,
  }) {
    return _send(
      method: 'PUT',
      path: path,
      body: body,
      bearerToken: bearerToken,
    );
  }

  Future<String> resolveBaseUrl() async {
    final configuredBaseUrl = (await _database.loadAppSetting(
      apiBaseUrlSettingKey,
    ))?.trim();
    return _normalizeBaseUrl(
      configuredBaseUrl?.isNotEmpty == true
          ? configuredBaseUrl!
          : _defaultBaseUrl ??
                (_configuredBaseUrl.isNotEmpty
                    ? _configuredBaseUrl
                    : defaultBaseUrlForCurrentPlatform),
    );
  }

  Future<dynamic> _send({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Object? body,
    String? bearerToken,
  }) async {
    final uri = await _buildUri(path, queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
    };

    http.Response response;
    try {
      response = switch (method) {
        'GET' =>
          await _httpClient
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15)),
        'POST' =>
          await _httpClient
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20)),
        'PUT' =>
          await _httpClient
              .put(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20)),
        _ => throw ApiException('Metodo HTTP nao suportado: $method'),
      };
    } on TimeoutException catch (error, stackTrace) {
      _logger.error('Tempo esgotado ao chamar $uri.', error, stackTrace);
      throw const ApiException(
        'Tempo esgotado ao conectar com o backend Tatuzin.',
      );
    } catch (error, stackTrace) {
      _logger.error('Falha de rede ao chamar $uri.', error, stackTrace);
      throw const ApiException(
        'Nao foi possivel conectar com o backend Tatuzin.',
      );
    }

    final decodedBody = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    throw ApiException(
      _extractMessage(decodedBody) ??
          'Falha na comunicacao com o backend Tatuzin.',
      statusCode: response.statusCode,
      responseBody: decodedBody,
    );
  }

  Future<String> _sendText({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    String? bearerToken,
  }) async {
    final uri = await _buildUri(path, queryParameters);
    final headers = <String, String>{
      'Accept': 'text/csv, text/plain, */*',
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
    };

    http.Response response;
    try {
      response = switch (method) {
        'GET' =>
          await _httpClient
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15)),
        _ => throw ApiException('Metodo HTTP nao suportado: $method'),
      };
    } on TimeoutException catch (error, stackTrace) {
      _logger.error('Tempo esgotado ao chamar $uri.', error, stackTrace);
      throw const ApiException(
        'Tempo esgotado ao conectar com o backend Tatuzin.',
      );
    } catch (error, stackTrace) {
      _logger.error('Falha de rede ao chamar $uri.', error, stackTrace);
      throw const ApiException(
        'Nao foi possivel conectar com o backend Tatuzin.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }

    dynamic decodedBody;
    try {
      decodedBody = response.body.isEmpty ? null : jsonDecode(response.body);
    } on Object {
      decodedBody = null;
    }

    final plainTextMessage = response.body.trim();
    throw ApiException(
      _extractMessage(decodedBody) ??
          (plainTextMessage.isEmpty
              ? 'Falha na comunicacao com o backend Tatuzin.'
              : plainTextMessage),
      statusCode: response.statusCode,
      responseBody: decodedBody ?? response.body,
    );
  }

  Future<Uri> _buildUri(
    String path,
    Map<String, String>? queryParameters,
  ) async {
    final baseUrl = await resolveBaseUrl();
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  String? _extractMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  static String get defaultBaseUrlForCurrentPlatform {
    if (kReleaseMode) {
      return _releaseBaseUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3333';
    }
    return 'http://127.0.0.1:3333';
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final dynamic responseBody;

  @override
  String toString() => message;
}
