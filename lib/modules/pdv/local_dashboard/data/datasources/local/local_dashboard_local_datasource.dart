import '../../../../../../core/database/app_database.dart';
import '../../../application/dtos/local_dashboard_snapshot.dart';
import '../../../domain/entities/local_dashboard_summary.dart';
import '../../../domain/entities/recent_local_sale.dart';
import '../../../../payments/domain/entities/payment_method.dart';
import '../../../../payments/domain/entities/payment_status.dart';

class LocalDashboardLocalDatasource {
  const LocalDashboardLocalDatasource({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<LocalDashboardSnapshot> loadSnapshotForCashSession(
    String cashSessionLocalId,
  ) async {
    final db = await _database.database;

    final summaryRows = await db.rawQuery(
      '''
      SELECT
        COALESCE((SELECT SUM(total_cents) FROM sales WHERE cash_session_local_id = ?), 0) AS total_sold_cents,
        COALESCE((
          SELECT SUM(si.quantity)
          FROM sale_items si
          INNER JOIN sales s ON s.local_id = si.sale_local_id
          WHERE s.cash_session_local_id = ?
        ), 0) AS total_items_sold,
        COALESCE((SELECT COUNT(*) FROM sales WHERE cash_session_local_id = ?), 0) AS total_sales,
        COALESCE((
          SELECT SUM(p.amount_cents)
          FROM payments p
          INNER JOIN sales s ON s.local_id = p.sale_local_id
          WHERE s.cash_session_local_id = ? AND p.method = 'cash'
        ), 0) AS cash_sales_cents,
        COALESCE((
          SELECT SUM(p.amount_cents)
          FROM payments p
          INNER JOIN sales s ON s.local_id = p.sale_local_id
          WHERE s.cash_session_local_id = ? AND p.method = 'pix'
        ), 0) AS pix_sales_cents,
        COALESCE((
          SELECT SUM(p.amount_cents)
          FROM payments p
          INNER JOIN sales s ON s.local_id = p.sale_local_id
          WHERE s.cash_session_local_id = ? AND p.method = 'note'
        ), 0) AS note_sales_cents,
        COALESCE((
          SELECT SUM(pt.outstanding_amount_cents)
          FROM payment_terms pt
          INNER JOIN sales s ON s.local_id = pt.sale_local_id
          WHERE s.cash_session_local_id = ?
        ), 0) AS outstanding_note_amount_cents
      ''',
      <Object>[
        cashSessionLocalId,
        cashSessionLocalId,
        cashSessionLocalId,
        cashSessionLocalId,
        cashSessionLocalId,
        cashSessionLocalId,
        cashSessionLocalId,
      ],
    );

    final recentRows = await db.rawQuery(
      '''
      SELECT
        s.local_id AS sale_local_id,
        s.created_at AS created_at,
        s.total_cents AS total_cents,
        COUNT(si.local_id) AS item_count,
        p.method AS payment_method,
        r.pdf_path AS receipt_path,
        qc.name AS customer_name,
        pt.payment_status AS payment_status,
        pt.outstanding_amount_cents AS outstanding_amount_cents
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_local_id = s.local_id
      LEFT JOIN payments p ON p.sale_local_id = s.local_id
      LEFT JOIN receipts r ON r.sale_local_id = s.local_id
      LEFT JOIN quick_customers qc ON qc.local_id = s.customer_local_id
      LEFT JOIN payment_terms pt ON pt.sale_local_id = s.local_id
      WHERE s.cash_session_local_id = ?
      GROUP BY
        s.local_id,
        s.created_at,
        s.total_cents,
        p.method,
        r.pdf_path,
        qc.name,
        pt.payment_status,
        pt.outstanding_amount_cents
      ORDER BY s.created_at DESC
      LIMIT 8
      ''',
      <Object>[cashSessionLocalId],
    );

    final summaryRow = summaryRows.first;
    final summary = LocalDashboardSummary(
      totalSoldInCents: (summaryRow['total_sold_cents'] as num?)?.toInt() ?? 0,
      totalItemsSold: (summaryRow['total_items_sold'] as num?)?.toInt() ?? 0,
      totalSales: (summaryRow['total_sales'] as num?)?.toInt() ?? 0,
      cashSalesInCents: (summaryRow['cash_sales_cents'] as num?)?.toInt() ?? 0,
      pixSalesInCents: (summaryRow['pix_sales_cents'] as num?)?.toInt() ?? 0,
      noteSalesInCents: (summaryRow['note_sales_cents'] as num?)?.toInt() ?? 0,
      outstandingNoteAmountInCents:
          (summaryRow['outstanding_note_amount_cents'] as num?)?.toInt() ?? 0,
    );

    final recentSales = recentRows.map((row) {
      return RecentLocalSale(
        saleLocalId: row['sale_local_id']! as String,
        createdAt: DateTime.parse(row['created_at']! as String),
        totalInCents: (row['total_cents'] as num?)?.toInt() ?? 0,
        itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
        paymentMethod: PaymentMethod.values.firstWhere(
          (value) => value.wireValue == row['payment_method'],
          orElse: () => PaymentMethod.cash,
        ),
        receiptPath: row['receipt_path']! as String,
        customerName: row['customer_name'] as String?,
        paymentStatus: row['payment_status'] == null
            ? null
            : PaymentStatus.values.firstWhere(
                (value) => value.wireValue == row['payment_status'],
                orElse: () => PaymentStatus.pending,
              ),
        outstandingAmountInCents: (row['outstanding_amount_cents'] as num?)
            ?.toInt(),
      );
    }).toList();

    return LocalDashboardSnapshot(summary: summary, recentSales: recentSales);
  }
}
