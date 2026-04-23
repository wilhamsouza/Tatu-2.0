class LocalDashboardSummary {
  const LocalDashboardSummary({
    required this.totalSoldInCents,
    required this.totalItemsSold,
    required this.totalSales,
    required this.cashSalesInCents,
    required this.pixSalesInCents,
    required this.noteSalesInCents,
    required this.outstandingNoteAmountInCents,
  });

  final int totalSoldInCents;
  final int totalItemsSold;
  final int totalSales;
  final int cashSalesInCents;
  final int pixSalesInCents;
  final int noteSalesInCents;
  final int outstandingNoteAmountInCents;
}
