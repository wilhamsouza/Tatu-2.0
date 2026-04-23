import '../../domain/entities/local_dashboard_summary.dart';
import '../../domain/entities/recent_local_sale.dart';

class LocalDashboardSnapshot {
  const LocalDashboardSnapshot({
    required this.summary,
    required this.recentSales,
  });

  final LocalDashboardSummary summary;
  final List<RecentLocalSale> recentSales;
}
