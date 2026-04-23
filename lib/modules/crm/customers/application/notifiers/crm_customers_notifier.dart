import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../domain/entities/crm_entities.dart';
import '../../domain/repositories/crm_repository.dart';
import '../../presentation/providers/crm_providers.dart';

final crmCustomersNotifierProvider =
    AsyncNotifierProvider<CrmCustomersNotifier, CrmDirectoryState>(
      CrmCustomersNotifier.new,
    );

class CrmCustomersNotifier extends AsyncNotifier<CrmDirectoryState> {
  CrmRepository get _repository => ref.read(crmRepositoryProvider);

  @override
  Future<CrmDirectoryState> build() async {
    ref.watch(sessionNotifierProvider);
    return _loadState();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadState);
  }

  Future<void> search(String query) async {
    final previous = state.asData?.value ?? const CrmDirectoryState.empty();
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _loadState(query: query, previous: previous),
    );
  }

  Future<void> selectCustomer(String customerId) async {
    final accessToken = _currentAccessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const CrmNotifierException('Sessao invalida para acessar o CRM.');
    }

    final current = state.asData?.value ?? const CrmDirectoryState.empty();
    final summary = await _repository.loadCustomerSummary(
      accessToken: accessToken,
      customerId: customerId,
    );
    final history = await _repository.loadCustomerHistory(
      accessToken: accessToken,
      customerId: customerId,
    );

    state = AsyncData(
      current.copyWith(
        selectedCustomerId: customerId,
        selectedSummary: summary,
        selectedHistory: history,
      ),
    );
  }

  Future<void> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final accessToken = _currentAccessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const CrmNotifierException('Sessao invalida para operar o CRM.');
    }

    final created = await _repository.createCustomer(
      accessToken: accessToken,
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
    state = AsyncData(await _loadState(query: ''));
    await selectCustomer(created.id);
  }

  Future<void> updateCustomer({
    required String customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final accessToken = _currentAccessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const CrmNotifierException('Sessao invalida para operar o CRM.');
    }

    await _repository.updateCustomer(
      accessToken: accessToken,
      customerId: customerId,
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
    await refresh();
    await selectCustomer(customerId);
  }

  Future<String> exportCurrentSegmentCsv() async {
    final accessToken = _currentAccessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const CrmNotifierException('Sessao invalida para exportar CRM.');
    }

    final query = state.asData?.value.query;
    return _repository.exportSegmentCsv(accessToken: accessToken, query: query);
  }

  Future<CrmDirectoryState> _loadState({
    String? query,
    CrmDirectoryState? previous,
  }) async {
    final accessToken = _currentAccessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return const CrmDirectoryState.empty();
    }

    final baseState =
        previous ?? state.asData?.value ?? const CrmDirectoryState.empty();
    final effectiveQuery = query ?? baseState.query;
    final customers = await _repository.listCustomers(
      accessToken: accessToken,
      query: effectiveQuery,
    );

    final selectedCustomerId = baseState.selectedCustomerId;
    if (selectedCustomerId == null ||
        customers.every((customer) => customer.id != selectedCustomerId)) {
      return CrmDirectoryState(query: effectiveQuery, customers: customers);
    }

    final summary = await _repository.loadCustomerSummary(
      accessToken: accessToken,
      customerId: selectedCustomerId,
    );
    final history = await _repository.loadCustomerHistory(
      accessToken: accessToken,
      customerId: selectedCustomerId,
    );

    return CrmDirectoryState(
      query: effectiveQuery,
      customers: customers,
      selectedCustomerId: selectedCustomerId,
      selectedSummary: summary,
      selectedHistory: history,
    );
  }

  String? get _currentAccessToken =>
      ref.read(sessionNotifierProvider).asData?.value?.tokens.accessToken;
}

class CrmNotifierException implements Exception {
  const CrmNotifierException(this.message);

  final String message;

  @override
  String toString() => message;
}
