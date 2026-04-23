import 'package:flutter_test/flutter_test.dart';
import 'package:tatuzin/core/sync/domain/entities/sync_record_status.dart';
import 'package:tatuzin/modules/pdv/payments/domain/entities/payment_status.dart';
import 'package:tatuzin/modules/pdv/payments/domain/entities/payment_term.dart';

void main() {
  group('PaymentTerm', () {
    test('creates a pending note when due date is in the future', () {
      final term = PaymentTerm.createNote(
        localId: 'term_001',
        saleLocalId: 'sale_001',
        customerLocalId: 'customer_001',
        originalAmountInCents: 15000,
        dueDate: DateTime.utc(2026, 5, 5),
        now: DateTime.utc(2026, 4, 21),
      );

      expect(term.paymentStatus, PaymentStatus.pending);
      expect(term.outstandingAmountInCents, 15000);
      expect(term.syncStatus, SyncRecordStatus.pending);
    });

    test('blocks settlement above the outstanding amount', () {
      final term = PaymentTerm.createNote(
        localId: 'term_002',
        saleLocalId: 'sale_002',
        customerLocalId: 'customer_001',
        originalAmountInCents: 10000,
        dueDate: DateTime.utc(2026, 5, 5),
        now: DateTime.utc(2026, 4, 21),
      );

      expect(
        () => term.applySettlement(
          amountInCents: 11000,
          paidAt: DateTime.utc(2026, 4, 22),
        ),
        throwsA(isA<PaymentTermException>()),
      );
    });

    test('marks a note as paid after full settlement', () {
      final term = PaymentTerm.createNote(
        localId: 'term_003',
        saleLocalId: 'sale_003',
        customerLocalId: 'customer_001',
        originalAmountInCents: 18000,
        dueDate: DateTime.utc(2026, 5, 5),
        now: DateTime.utc(2026, 4, 21),
      );

      final settled = term.applySettlement(
        amountInCents: 18000,
        paidAt: DateTime.utc(2026, 4, 22),
      );

      expect(settled.paymentStatus, PaymentStatus.paid);
      expect(settled.outstandingAmountInCents, 0);
      expect(settled.paidAmountInCents, 18000);
    });
  });
}
