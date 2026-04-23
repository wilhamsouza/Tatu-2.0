import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../../../core/database/app_database.dart';
import '../../../../../../core/database/local_database_executor.dart';
import '../../../../../../core/sync/domain/entities/sync_record_status.dart';
import '../../../../cash_register/data/datasources/local/cash_register_local_datasource.dart';
import '../../../../cash_register/domain/entities/cash_movement_type.dart';
import '../../../domain/entities/payment_method.dart';
import '../../../domain/entities/payment_status.dart';
import '../../../domain/entities/payment_term.dart';
import '../../../domain/entities/receivable_payment_local.dart';
import '../../../domain/entities/settlement_payment_method.dart';

class ReceivablePaymentLocalDatasource {
  ReceivablePaymentLocalDatasource({
    required AppDatabase database,
    required CashRegisterLocalDatasource cashRegisterLocalDatasource,
    Uuid? uuid,
  }) : _database = database,
       _cashRegisterLocalDatasource = cashRegisterLocalDatasource,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final CashRegisterLocalDatasource _cashRegisterLocalDatasource;
  final Uuid _uuid;

  Future<ReceivablePaymentLocal> registerSettlement({
    required String companyId,
    required String userId,
    required String deviceId,
    required String paymentTermLocalId,
    required String cashSessionLocalId,
    required int amountInCents,
    required SettlementPaymentMethod settlementMethod,
    String? notes,
    DateTime? paidAt,
  }) async {
    if (amountInCents <= 0) {
      throw const ReceivablePaymentException(
        'Baixa deve possuir valor maior que zero.',
      );
    }

    final db = await _database.database;
    final sessionRows = await db.query(
      'cash_sessions',
      where: 'local_id = ? AND status = ?',
      whereArgs: <Object>[cashSessionLocalId, 'open'],
      limit: 1,
    );
    if (sessionRows.isEmpty) {
      throw const ReceivablePaymentException(
        'Baixa de nota exige uma sessao de caixa aberta.',
      );
    }

    final termRows = await db.query(
      'payment_terms',
      where: 'local_id = ?',
      whereArgs: <Object>[paymentTermLocalId],
      limit: 1,
    );
    if (termRows.isEmpty) {
      throw const ReceivablePaymentException('Nota local nao encontrada.');
    }

    final term = _mapPaymentTerm(termRows.first);
    final timestamp = (paidAt ?? DateTime.now()).toUtc();
    final updatedTerm = term.applySettlement(
      amountInCents: amountInCents,
      paidAt: timestamp,
    );
    final payment = ReceivablePaymentLocal(
      localId: _uuid.v4(),
      paymentTermLocalId: paymentTermLocalId,
      amountInCents: amountInCents,
      paymentMethodUsedForSettlement: settlementMethod,
      paidAt: timestamp,
      notes: _normalizeOptional(notes),
      createdByUserId: userId,
      cashSessionLocalId: cashSessionLocalId,
      createdAt: timestamp,
      syncStatus: SyncRecordStatus.pending,
    );

    await db.transaction((txn) async {
      await txn.insert('receivable_payments', <String, Object?>{
        'local_id': payment.localId,
        'payment_term_local_id': payment.paymentTermLocalId,
        'remote_id': payment.remoteId,
        'amount_cents': payment.amountInCents,
        'payment_method_used_for_settlement':
            payment.paymentMethodUsedForSettlement.wireValue,
        'paid_at': payment.paidAt.toIso8601String(),
        'notes': payment.notes,
        'created_by_user_id': payment.createdByUserId,
        'cash_session_local_id': payment.cashSessionLocalId,
        'created_at': payment.createdAt.toIso8601String(),
        'sync_status': payment.syncStatus.wireValue,
      });

      await txn.update(
        'payment_terms',
        <String, Object?>{
          'paid_amount_cents': updatedTerm.paidAmountInCents,
          'outstanding_amount_cents': updatedTerm.outstandingAmountInCents,
          'payment_status': updatedTerm.paymentStatus.wireValue,
          'sync_status': SyncRecordStatus.pending.wireValue,
          'updated_at': updatedTerm.updatedAt.toIso8601String(),
        },
        where: 'local_id = ?',
        whereArgs: <Object>[paymentTermLocalId],
      );

      final movementType = switch (settlementMethod) {
        SettlementPaymentMethod.cash =>
          CashMovementType.receivableSettlementCash,
        SettlementPaymentMethod.pix => CashMovementType.receivableSettlementPix,
      };

      await _cashRegisterLocalDatasource
          .insertReceivableSettlementMovementInTransaction(
            executor: txn,
            companyId: companyId,
            deviceId: deviceId,
            cashSessionLocalId: cashSessionLocalId,
            type: movementType,
            amountInCents: amountInCents,
            receivablePaymentLocalId: payment.localId,
            paymentTermLocalId: paymentTermLocalId,
            notes: payment.notes,
          );

      await _insertOutbox(
        executor: txn,
        operationType: 'receivable_settlement',
        entityLocalId: payment.localId,
        companyId: companyId,
        deviceId: deviceId,
        payload: <String, Object?>{
          'receivablePaymentLocalId': payment.localId,
          'paymentTermLocalId': payment.paymentTermLocalId,
          'paymentTermRemoteId': term.remoteId,
          'saleLocalId': term.saleLocalId,
          'amountInCents': payment.amountInCents,
          'settlementMethod': payment.paymentMethodUsedForSettlement.wireValue,
          'paidAt': payment.paidAt.toIso8601String(),
          'notes': payment.notes,
          'cashSessionLocalId': payment.cashSessionLocalId,
        },
      );
    });

    return payment;
  }

  PaymentTerm _mapPaymentTerm(Map<String, Object?> row) {
    return PaymentTerm(
      localId: row['local_id']! as String,
      saleLocalId: row['sale_local_id']! as String,
      remoteId: row['remote_id'] as String?,
      customerLocalId: row['customer_local_id'] as String?,
      customerRemoteId: row['customer_remote_id'] as String?,
      paymentMethod: _paymentMethodFromWire(row['payment_method']! as String),
      originalAmountInCents: row['original_amount_cents']! as int,
      paidAmountInCents: row['paid_amount_cents']! as int,
      outstandingAmountInCents: row['outstanding_amount_cents']! as int,
      dueDate: DateTime.parse(row['due_date']! as String),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      paymentStatus: _paymentStatusFromWire(row['payment_status']! as String),
      notes: row['notes'] as String?,
      syncStatus: SyncRecordStatus.fromWireValue(row['sync_status']! as String),
    );
  }

  PaymentMethod _paymentMethodFromWire(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.wireValue == value,
      orElse: () => PaymentMethod.note,
    );
  }

  PaymentStatus _paymentStatusFromWire(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => PaymentStatus.pending,
    );
  }

  Future<void> _insertOutbox({
    required LocalDatabaseExecutor executor,
    required String operationType,
    required String entityLocalId,
    required String companyId,
    required String deviceId,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await executor.insert('sync_outbox', <String, Object?>{
      'operation_id': _uuid.v4(),
      'device_id': deviceId,
      'company_id': companyId,
      'type': operationType,
      'entity_local_id': entityLocalId,
      'payload_json': jsonEncode(payload),
      'status': SyncRecordStatus.pending.wireValue,
      'retries': 0,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
    });
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class ReceivablePaymentException implements Exception {
  const ReceivablePaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}
