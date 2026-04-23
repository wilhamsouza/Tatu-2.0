import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../data/datasources/local/cash_register_local_datasource.dart';
import '../../domain/entities/cash_movement_type.dart';
import '../../domain/entities/cash_session_summary.dart';
import '../../domain/repositories/cash_register_repository.dart';
import '../../data/repositories/local_cash_register_repository.dart';
import '../../../../../core/database/providers/database_providers.dart';

final cashRegisterLocalDatasourceProvider =
    Provider<CashRegisterLocalDatasource>((ref) {
      return CashRegisterLocalDatasource(
        database: ref.read(appDatabaseProvider),
      );
    });

final cashRegisterRepositoryProvider = Provider<CashRegisterRepository>((ref) {
  return LocalCashRegisterRepository(
    localDatasource: ref.read(cashRegisterLocalDatasourceProvider),
  );
});

final cashRegisterNotifierProvider =
    AsyncNotifierProvider<CashRegisterNotifier, CashSessionSummary?>(
      CashRegisterNotifier.new,
    );

class CashRegisterNotifier extends AsyncNotifier<CashSessionSummary?> {
  CashRegisterRepository get _repository =>
      ref.read(cashRegisterRepositoryProvider);

  @override
  Future<CashSessionSummary?> build() {
    return _repository.loadOpenSessionSummary();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.loadOpenSessionSummary());
  }

  Future<void> openSession(int openingAmountInCents) async {
    final session = ref.read(sessionNotifierProvider).asData?.value;
    if (session == null) {
      throw const CashRegisterException('Sessao invalida para abrir caixa.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.openSession(
        companyId: session.companyContext.companyId,
        userId: session.user.userId,
        deviceId: session.deviceRegistration.deviceId,
        openingAmountInCents: openingAmountInCents,
      ),
    );
  }

  Future<void> registerMovement({
    required CashMovementType type,
    required int amountInCents,
    String? notes,
  }) async {
    final session = ref.read(sessionNotifierProvider).asData?.value;
    final summary = state.asData?.value;
    if (session == null || summary == null) {
      throw const CashRegisterException(
        'Abra um caixa antes de registrar movimentos.',
      );
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.registerMovement(
        companyId: session.companyContext.companyId,
        userId: session.user.userId,
        deviceId: session.deviceRegistration.deviceId,
        cashSessionLocalId: summary.session.localId,
        type: type,
        amountInCents: amountInCents,
        notes: notes,
      );
      return _repository.loadOpenSessionSummary();
    });
  }

  Future<void> closeSession() async {
    final session = ref.read(sessionNotifierProvider).asData?.value;
    final summary = state.asData?.value;
    if (session == null || summary == null) {
      throw const CashRegisterException('Nao ha caixa aberto para fechar.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.closeSession(
        companyId: session.companyContext.companyId,
        userId: session.user.userId,
        deviceId: session.deviceRegistration.deviceId,
        cashSessionLocalId: summary.session.localId,
      );
      return _repository.loadOpenSessionSummary();
    });
  }
}
