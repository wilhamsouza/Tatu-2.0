import '../../../../../core/sync/domain/entities/sync_record_status.dart';
import 'payment_method.dart';
import 'payment_status.dart';

class PaymentTerm {
  const PaymentTerm({
    required this.localId,
    required this.saleLocalId,
    this.remoteId,
    this.customerLocalId,
    this.customerRemoteId,
    required this.paymentMethod,
    required this.originalAmountInCents,
    required this.paidAmountInCents,
    required this.outstandingAmountInCents,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.paymentStatus,
    this.notes,
    required this.syncStatus,
  });

  final String localId;
  final String saleLocalId;
  final String? remoteId;
  final String? customerLocalId;
  final String? customerRemoteId;
  final PaymentMethod paymentMethod;
  final int originalAmountInCents;
  final int paidAmountInCents;
  final int outstandingAmountInCents;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PaymentStatus paymentStatus;
  final String? notes;
  final SyncRecordStatus syncStatus;

  factory PaymentTerm.createNote({
    required String localId,
    required String saleLocalId,
    String? customerLocalId,
    String? customerRemoteId,
    required int originalAmountInCents,
    required DateTime dueDate,
    String? notes,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    if (originalAmountInCents <= 0) {
      throw const PaymentTermException(
        'Pagamento em nota precisa ter valor original maior que zero.',
      );
    }

    final status = _resolveStatus(
      dueDate: dueDate,
      outstandingAmountInCents: originalAmountInCents,
      paidAmountInCents: 0,
      now: timestamp,
    );

    return PaymentTerm(
      localId: localId,
      saleLocalId: saleLocalId,
      customerLocalId: customerLocalId,
      customerRemoteId: customerRemoteId,
      paymentMethod: PaymentMethod.note,
      originalAmountInCents: originalAmountInCents,
      paidAmountInCents: 0,
      outstandingAmountInCents: originalAmountInCents,
      dueDate: dueDate.toUtc(),
      createdAt: timestamp,
      updatedAt: timestamp,
      paymentStatus: status,
      notes: notes,
      syncStatus: SyncRecordStatus.pending,
    );
  }

  PaymentTerm applySettlement({
    required int amountInCents,
    required DateTime paidAt,
  }) {
    if (amountInCents <= 0) {
      throw const PaymentTermException(
        'Baixa deve possuir valor maior que zero.',
      );
    }
    if (amountInCents > outstandingAmountInCents) {
      throw const PaymentTermException(
        'Baixa não pode ultrapassar o saldo em aberto.',
      );
    }

    final nextPaid = paidAmountInCents + amountInCents;
    final nextOutstanding = originalAmountInCents - nextPaid;
    final nextStatus = _resolveStatus(
      dueDate: dueDate,
      outstandingAmountInCents: nextOutstanding,
      paidAmountInCents: nextPaid,
      now: paidAt.toUtc(),
    );

    return PaymentTerm(
      localId: localId,
      saleLocalId: saleLocalId,
      remoteId: remoteId,
      customerLocalId: customerLocalId,
      customerRemoteId: customerRemoteId,
      paymentMethod: paymentMethod,
      originalAmountInCents: originalAmountInCents,
      paidAmountInCents: nextPaid,
      outstandingAmountInCents: nextOutstanding.clamp(0, originalAmountInCents),
      dueDate: dueDate,
      createdAt: createdAt,
      updatedAt: paidAt.toUtc(),
      paymentStatus: nextStatus,
      notes: notes,
      syncStatus: SyncRecordStatus.pending,
    );
  }

  static PaymentStatus _resolveStatus({
    required DateTime dueDate,
    required int outstandingAmountInCents,
    required int paidAmountInCents,
    required DateTime now,
  }) {
    if (outstandingAmountInCents <= 0) {
      return PaymentStatus.paid;
    }

    final due = _dateOnly(dueDate);
    final today = _dateOnly(now);
    final isOverdue = due.isBefore(today);

    if (isOverdue) {
      return PaymentStatus.overdue;
    }

    if (paidAmountInCents > 0) {
      return PaymentStatus.partiallyPaid;
    }

    return PaymentStatus.pending;
  }

  static DateTime _dateOnly(DateTime value) {
    final normalized = value.toUtc();
    return DateTime.utc(normalized.year, normalized.month, normalized.day);
  }
}

class PaymentTermException implements Exception {
  const PaymentTermException(this.message);

  final String message;

  @override
  String toString() => message;
}
