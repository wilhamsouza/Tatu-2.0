import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/cash_movement_type.dart';
import '../../domain/entities/cash_session_summary.dart';
import '../../domain/repositories/cash_register_repository.dart';
import '../datasources/local/cash_register_local_datasource.dart';

class LocalCashRegisterRepository implements CashRegisterRepository {
  const LocalCashRegisterRepository({
    required CashRegisterLocalDatasource localDatasource,
  }) : _localDatasource = localDatasource;

  final CashRegisterLocalDatasource _localDatasource;

  @override
  Future<void> closeSession({
    required String companyId,
    required String userId,
    required String deviceId,
    required String cashSessionLocalId,
  }) {
    return _localDatasource.closeSession(
      companyId: companyId,
      userId: userId,
      deviceId: deviceId,
      cashSessionLocalId: cashSessionLocalId,
    );
  }

  @override
  Future<CashSessionSummary?> loadOpenSessionSummary() {
    return _localDatasource.loadOpenSessionSummary();
  }

  @override
  Future<CashSessionSummary> openSession({
    required String companyId,
    required String userId,
    required String deviceId,
    required int openingAmountInCents,
  }) {
    return _localDatasource.openSession(
      companyId: companyId,
      userId: userId,
      deviceId: deviceId,
      openingAmountInCents: openingAmountInCents,
    );
  }

  @override
  Future<CashMovement> registerMovement({
    required String companyId,
    required String userId,
    required String deviceId,
    required String cashSessionLocalId,
    required CashMovementType type,
    required int amountInCents,
    String? notes,
  }) {
    return _localDatasource.registerMovement(
      companyId: companyId,
      userId: userId,
      deviceId: deviceId,
      cashSessionLocalId: cashSessionLocalId,
      type: type,
      amountInCents: amountInCents,
      notes: notes,
    );
  }
}
