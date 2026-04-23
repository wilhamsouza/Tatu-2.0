import 'cash_session.dart';

class CashSessionSummary {
  const CashSessionSummary({
    required this.session,
    required this.cashSalesInCents,
    required this.pixSalesInCents,
    required this.noteSalesInCents,
    required this.suppliesInCents,
    required this.withdrawalsInCents,
    required this.receivableSettlementCashInCents,
    required this.receivableSettlementPixInCents,
    required this.totalSalesCount,
  });

  final CashSession session;
  final int cashSalesInCents;
  final int pixSalesInCents;
  final int noteSalesInCents;
  final int suppliesInCents;
  final int withdrawalsInCents;
  final int receivableSettlementCashInCents;
  final int receivableSettlementPixInCents;
  final int totalSalesCount;

  int get expectedCashBalanceInCents =>
      session.openingAmountInCents +
      cashSalesInCents +
      suppliesInCents -
      withdrawalsInCents +
      receivableSettlementCashInCents;

  int get grossSalesInCents =>
      cashSalesInCents + pixSalesInCents + noteSalesInCents;

  int get totalReceivableSettlementsInCents =>
      receivableSettlementCashInCents + receivableSettlementPixInCents;
}
