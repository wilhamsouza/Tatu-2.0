import '../entities/cash_movement.dart';
import '../entities/cash_movement_type.dart';
import '../entities/cash_session_summary.dart';

abstract class CashRegisterRepository {
  Future<CashSessionSummary?> loadOpenSessionSummary();

  Future<CashSessionSummary> openSession({
    required String companyId,
    required String userId,
    required String deviceId,
    required int openingAmountInCents,
  });

  Future<CashMovement> registerMovement({
    required String companyId,
    required String userId,
    required String deviceId,
    required String cashSessionLocalId,
    required CashMovementType type,
    required int amountInCents,
    String? notes,
  });

  Future<void> closeSession({
    required String companyId,
    required String userId,
    required String deviceId,
    required String cashSessionLocalId,
  });
}
