import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../../../core/database/app_database.dart';
import '../../../../../../core/database/local_database_executor.dart';
import '../../../../../../core/sync/domain/entities/sync_record_status.dart';
import '../../../domain/entities/cash_movement.dart';
import '../../../domain/entities/cash_movement_type.dart';
import '../../../domain/entities/cash_session.dart';
import '../../../domain/entities/cash_session_summary.dart';

class CashRegisterLocalDatasource {
  CashRegisterLocalDatasource({required AppDatabase database, Uuid? uuid})
    : _database = database,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<CashSessionSummary?> loadOpenSessionSummary() async {
    final db = await _database.database;
    final openSessionRows = await db.query(
      'cash_sessions',
      where: 'status = ?',
      whereArgs: <Object>['open'],
      orderBy: 'opened_at DESC',
      limit: 1,
    );

    if (openSessionRows.isEmpty) {
      return null;
    }

    final session = _mapCashSession(openSessionRows.first);
    return _loadSummaryForSession(db, session);
  }

  Future<CashSessionSummary> openSession({
    required String companyId,
    required String userId,
    required String deviceId,
    required int openingAmountInCents,
  }) async {
    if (openingAmountInCents < 0) {
      throw const CashRegisterException(
        'Abertura de caixa nao aceita valor negativo.',
      );
    }

    final existing = await loadOpenSessionSummary();
    if (existing != null) {
      throw const CashRegisterException(
        'Ja existe um caixa aberto neste dispositivo.',
      );
    }

    final db = await _database.database;
    final now = DateTime.now().toUtc();
    final session = CashSession(
      localId: _uuid.v4(),
      userId: userId,
      openingAmountInCents: openingAmountInCents,
      status: 'open',
      openedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('cash_sessions', <String, Object?>{
        'local_id': session.localId,
        'remote_id': session.remoteId,
        'user_id': session.userId,
        'opening_amount_cents': session.openingAmountInCents,
        'status': session.status,
        'opened_at': session.openedAt.toIso8601String(),
        'closed_at': null,
      });

      await _insertCashMovement(
        executor: txn,
        companyId: companyId,
        deviceId: deviceId,
        cashMovement: CashMovement(
          localId: _uuid.v4(),
          cashSessionLocalId: session.localId,
          type: CashMovementType.opening,
          amountInCents: openingAmountInCents,
          syncStatus: SyncRecordStatus.pending,
          createdAt: now,
        ),
        payload: <String, Object?>{
          'cashSessionLocalId': session.localId,
          'type': CashMovementType.opening.wireValue,
          'amountInCents': openingAmountInCents,
          'openedAt': now.toIso8601String(),
        },
      );
    });

    return (await loadOpenSessionSummary())!;
  }

  Future<CashMovement> registerMovement({
    required String companyId,
    required String userId,
    required String deviceId,
    required String cashSessionLocalId,
    required CashMovementType type,
    required int amountInCents,
    String? notes,
  }) async {
    if (amountInCents <= 0) {
      throw const CashRegisterException(
        'Movimento de caixa exige valor maior que zero.',
      );
    }
    if (type == CashMovementType.saleCash ||
        type == CashMovementType.salePix ||
        type == CashMovementType.saleNote ||
        type == CashMovementType.receivableSettlementCash ||
        type == CashMovementType.receivableSettlementPix ||
        type == CashMovementType.opening ||
        type == CashMovementType.closing) {
      throw const CashRegisterException(
        'Use o fluxo especifico para vendas, baixas, abertura e fechamento.',
      );
    }

    final now = DateTime.now().toUtc();
    final movement = CashMovement(
      localId: _uuid.v4(),
      cashSessionLocalId: cashSessionLocalId,
      type: type,
      amountInCents: amountInCents,
      notes: notes,
      syncStatus: SyncRecordStatus.pending,
      createdAt: now,
    );

    final db = await _database.database;
    await _insertCashMovement(
      executor: db,
      companyId: companyId,
      deviceId: deviceId,
      cashMovement: movement,
      payload: <String, Object?>{
        'cashSessionLocalId': cashSessionLocalId,
        'type': type.wireValue,
        'amountInCents': amountInCents,
        'notes': notes,
        'createdByUserId': userId,
        'createdAt': now.toIso8601String(),
      },
    );

    return movement;
  }

  Future<void> closeSession({
    required String companyId,
    required String userId,
    required String deviceId,
    required String cashSessionLocalId,
  }) async {
    final db = await _database.database;
    final sessionRows = await db.query(
      'cash_sessions',
      where: 'local_id = ? AND status = ?',
      whereArgs: <Object>[cashSessionLocalId, 'open'],
      limit: 1,
    );
    if (sessionRows.isEmpty) {
      throw const CashRegisterException(
        'Nenhum caixa aberto encontrado para fechamento.',
      );
    }

    final session = _mapCashSession(sessionRows.first);
    final summary = await _loadSummaryForSession(db, session);
    final now = DateTime.now().toUtc();

    await db.transaction((txn) async {
      await txn.update(
        'cash_sessions',
        <String, Object?>{
          'status': 'closed',
          'closed_at': now.toIso8601String(),
        },
        where: 'local_id = ?',
        whereArgs: <Object>[cashSessionLocalId],
      );

      await _insertCashMovement(
        executor: txn,
        companyId: companyId,
        deviceId: deviceId,
        cashMovement: CashMovement(
          localId: _uuid.v4(),
          cashSessionLocalId: cashSessionLocalId,
          type: CashMovementType.closing,
          amountInCents: summary.expectedCashBalanceInCents,
          notes: 'Fechamento da sessao',
          syncStatus: SyncRecordStatus.pending,
          createdAt: now,
        ),
        payload: <String, Object?>{
          'cashSessionLocalId': cashSessionLocalId,
          'type': CashMovementType.closing.wireValue,
          'amountInCents': summary.expectedCashBalanceInCents,
          'createdByUserId': userId,
          'createdAt': now.toIso8601String(),
        },
      );
    });
  }

  Future<CashSessionSummary> loadSummaryForSessionById(
    String cashSessionLocalId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'cash_sessions',
      where: 'local_id = ?',
      whereArgs: <Object>[cashSessionLocalId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const CashRegisterException('Sessao de caixa nao encontrada.');
    }

    return _loadSummaryForSession(db, _mapCashSession(rows.first));
  }

  Future<CashSessionSummary> _loadSummaryForSession(
    LocalDatabaseExecutor executor,
    CashSession session,
  ) async {
    final movementRows = await executor.query(
      'cash_movements',
      where: 'cash_session_local_id = ?',
      whereArgs: <Object>[session.localId],
    );

    var cashSales = 0;
    var pixSales = 0;
    var noteSales = 0;
    var supplies = 0;
    var withdrawals = 0;
    var receivableSettlementCash = 0;
    var receivableSettlementPix = 0;

    for (final row in movementRows) {
      final type = CashMovementType.fromWireValue(row['type']! as String);
      final amount = row['amount_cents']! as int;

      switch (type) {
        case CashMovementType.saleCash:
          cashSales += amount;
        case CashMovementType.salePix:
          pixSales += amount;
        case CashMovementType.saleNote:
          noteSales += amount;
        case CashMovementType.supply:
          supplies += amount;
        case CashMovementType.withdrawal:
          withdrawals += amount;
        case CashMovementType.receivableSettlementCash:
          receivableSettlementCash += amount;
        case CashMovementType.receivableSettlementPix:
          receivableSettlementPix += amount;
        case CashMovementType.opening:
        case CashMovementType.closing:
          break;
      }
    }

    final salesCountResult = await executor.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM sales
      WHERE cash_session_local_id = ?
      ''',
      <Object>[session.localId],
    );

    return CashSessionSummary(
      session: session,
      cashSalesInCents: cashSales,
      pixSalesInCents: pixSales,
      noteSalesInCents: noteSales,
      suppliesInCents: supplies,
      withdrawalsInCents: withdrawals,
      receivableSettlementCashInCents: receivableSettlementCash,
      receivableSettlementPixInCents: receivableSettlementPix,
      totalSalesCount: (salesCountResult.first['total'] as int?) ?? 0,
    );
  }

  Future<void> insertReceivableSettlementMovementInTransaction({
    required LocalDatabaseExecutor executor,
    required String companyId,
    required String deviceId,
    required String cashSessionLocalId,
    required CashMovementType type,
    required int amountInCents,
    required String receivablePaymentLocalId,
    required String paymentTermLocalId,
    String? notes,
  }) async {
    if (type != CashMovementType.receivableSettlementCash &&
        type != CashMovementType.receivableSettlementPix) {
      throw const CashRegisterException(
        'Tipo de movimento invalido para baixa de nota.',
      );
    }

    final now = DateTime.now().toUtc();
    final movement = CashMovement(
      localId: _uuid.v4(),
      cashSessionLocalId: cashSessionLocalId,
      type: type,
      amountInCents: amountInCents,
      notes: notes ?? 'Baixa da nota $paymentTermLocalId',
      syncStatus: SyncRecordStatus.pending,
      createdAt: now,
    );

    await _insertCashMovement(
      executor: executor,
      companyId: companyId,
      deviceId: deviceId,
      cashMovement: movement,
      payload: <String, Object?>{
        'cashSessionLocalId': cashSessionLocalId,
        'receivablePaymentLocalId': receivablePaymentLocalId,
        'paymentTermLocalId': paymentTermLocalId,
        'type': type.wireValue,
        'amountInCents': amountInCents,
        'notes': notes,
        'createdAt': now.toIso8601String(),
      },
    );
  }

  Future<void> insertSaleMovementInTransaction({
    required LocalDatabaseExecutor executor,
    required String companyId,
    required String deviceId,
    required String cashSessionLocalId,
    required CashMovementType type,
    required int amountInCents,
    required String saleLocalId,
  }) async {
    final now = DateTime.now().toUtc();
    final movement = CashMovement(
      localId: _uuid.v4(),
      cashSessionLocalId: cashSessionLocalId,
      type: type,
      amountInCents: amountInCents,
      notes: 'Movimento gerado pela venda $saleLocalId',
      syncStatus: SyncRecordStatus.pending,
      createdAt: now,
    );

    await _insertCashMovement(
      executor: executor,
      companyId: companyId,
      deviceId: deviceId,
      cashMovement: movement,
      payload: <String, Object?>{
        'cashSessionLocalId': cashSessionLocalId,
        'saleLocalId': saleLocalId,
        'type': type.wireValue,
        'amountInCents': amountInCents,
        'createdAt': now.toIso8601String(),
      },
    );
  }

  Future<void> _insertCashMovement({
    required LocalDatabaseExecutor executor,
    required String companyId,
    required String deviceId,
    required CashMovement cashMovement,
    required Map<String, Object?> payload,
  }) async {
    await executor.insert('cash_movements', <String, Object?>{
      'local_id': cashMovement.localId,
      'remote_id': cashMovement.remoteId,
      'cash_session_local_id': cashMovement.cashSessionLocalId,
      'type': cashMovement.type.wireValue,
      'amount_cents': cashMovement.amountInCents,
      'notes': cashMovement.notes,
      'sync_status': cashMovement.syncStatus.wireValue,
      'created_at': cashMovement.createdAt.toIso8601String(),
    });

    await executor.insert('sync_outbox', <String, Object?>{
      'operation_id': _uuid.v4(),
      'device_id': deviceId,
      'company_id': companyId,
      'type': 'cash_movement',
      'entity_local_id': cashMovement.localId,
      'payload_json': jsonEncode(payload),
      'status': SyncRecordStatus.pending.wireValue,
      'retries': 0,
      'last_error': null,
      'created_at': cashMovement.createdAt.toIso8601String(),
      'updated_at': cashMovement.createdAt.toIso8601String(),
    });
  }

  CashSession _mapCashSession(Map<String, Object?> row) {
    return CashSession(
      localId: row['local_id']! as String,
      remoteId: row['remote_id'] as String?,
      userId: row['user_id']! as String,
      openingAmountInCents: row['opening_amount_cents']! as int,
      status: row['status']! as String,
      openedAt: DateTime.parse(row['opened_at']! as String),
      closedAt: row['closed_at'] == null
          ? null
          : DateTime.parse(row['closed_at']! as String),
    );
  }
}

class CashRegisterException implements Exception {
  const CashRegisterException(this.message);

  final String message;

  @override
  String toString() => message;
}
