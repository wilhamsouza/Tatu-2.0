import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/modules/pdv/cash_register/data/datasources/local/cash_register_local_datasource.dart';
import 'package:tatuzin/modules/pdv/cash_register/domain/entities/cash_movement_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late CashRegisterLocalDatasource datasource;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'cash-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();
    datasource = CashRegisterLocalDatasource(database: database);
  });

  tearDown(() async {
    final path = await database.database.then((db) => db.path);
    await database.close();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('opens cash session and recalculates expected balance', () async {
    final opened = await datasource.openSession(
      companyId: 'company_tatuzin',
      userId: 'user_cashier',
      deviceId: 'device_001',
      openingAmountInCents: 10000,
    );

    await datasource.registerMovement(
      companyId: 'company_tatuzin',
      userId: 'user_cashier',
      deviceId: 'device_001',
      cashSessionLocalId: opened.session.localId,
      type: CashMovementType.supply,
      amountInCents: 2500,
      notes: 'Reforco de troco',
    );

    await datasource.registerMovement(
      companyId: 'company_tatuzin',
      userId: 'user_cashier',
      deviceId: 'device_001',
      cashSessionLocalId: opened.session.localId,
      type: CashMovementType.withdrawal,
      amountInCents: 1000,
      notes: 'Sangria',
    );

    final summary = await datasource.loadOpenSessionSummary();

    expect(summary, isNotNull);
    expect(summary!.expectedCashBalanceInCents, 11500);
    expect(summary.suppliesInCents, 2500);
    expect(summary.withdrawalsInCents, 1000);
  });
}
