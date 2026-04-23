import 'package:uuid/uuid.dart';

import '../../../../../../core/database/app_database.dart';
import '../../../../../../core/database/local_database_executor.dart';
import '../../../../../../core/sync/domain/entities/sync_record_status.dart';
import '../../../../../../core/utils/currency_utils.dart';
import '../../../domain/entities/quick_customer.dart';

class QuickCustomerLocalDatasource {
  QuickCustomerLocalDatasource({required AppDatabase database, Uuid? uuid})
    : _database = database,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<List<QuickCustomer>> search(String query) async {
    final db = await _database.database;
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <QuickCustomer>[];
    }

    final likeValue = '%$normalizedQuery%';
    final rows = await db.query(
      'quick_customers',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: <Object>[likeValue, likeValue],
      orderBy: 'updated_at DESC',
      limit: 6,
    );

    return rows.map(_mapQuickCustomer).toList();
  }

  Future<QuickCustomer?> findByPhone(
    String phone, {
    LocalDatabaseExecutor? executor,
  }) async {
    final normalizedPhone = CurrencyUtils.normalizePhone(phone);
    if (normalizedPhone.isEmpty) {
      return null;
    }

    final database = executor ?? await _database.database;
    final rows = await database.query(
      'quick_customers',
      where: 'phone = ?',
      whereArgs: <Object>[normalizedPhone],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapQuickCustomer(rows.first);
  }

  Future<QuickCustomerUpsertResult> upsertInTransaction({
    required LocalDatabaseExecutor executor,
    required String name,
    required String phone,
  }) async {
    final normalizedPhone = CurrencyUtils.normalizePhone(phone);
    final existing = await findByPhone(normalizedPhone, executor: executor);
    if (existing != null) {
      return QuickCustomerUpsertResult(customer: existing, created: false);
    }

    final now = DateTime.now().toUtc();
    final customer = QuickCustomer(
      localId: _uuid.v4(),
      name: name.trim(),
      phone: normalizedPhone,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncRecordStatus.pending,
    );

    await executor.insert('quick_customers', <String, Object?>{
      'local_id': customer.localId,
      'remote_id': customer.remoteId,
      'name': customer.name,
      'phone': customer.phone,
      'sync_status': customer.syncStatus.wireValue,
      'created_at': customer.createdAt.toIso8601String(),
      'updated_at': customer.updatedAt.toIso8601String(),
    });

    return QuickCustomerUpsertResult(customer: customer, created: true);
  }

  QuickCustomer _mapQuickCustomer(Map<String, Object?> row) {
    return QuickCustomer(
      localId: row['local_id']! as String,
      remoteId: row['remote_id'] as String?,
      name: row['name']! as String,
      phone: row['phone']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      syncStatus: SyncRecordStatus.fromWireValue(row['sync_status']! as String),
    );
  }
}

class QuickCustomerUpsertResult {
  const QuickCustomerUpsertResult({
    required this.customer,
    required this.created,
  });

  final QuickCustomer customer;
  final bool created;
}
