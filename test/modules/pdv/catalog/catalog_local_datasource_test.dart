import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/modules/pdv/catalog/data/datasources/local/catalog_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(
      logger: const AppLogger(),
      databasePathOverride: p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'catalog-test-${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    await database.initialize();
  });

  tearDown(() async {
    final path = await database.database.then((db) => db.path);
    await database.close();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('seeds local catalog and supports searching by category', () async {
    final datasource = CatalogLocalDatasource(database: database);

    await datasource.ensureSeeded();

    final categories = await datasource.listCategories();
    final jeans = await datasource.searchVariants(categoryName: 'Jeans');

    expect(categories, isNotEmpty);
    expect(categories.map((entry) => entry.name), contains('Jeans'));
    expect(jeans, hasLength(2));
  });

  test('supports searching by barcode or sku', () async {
    final datasource = CatalogLocalDatasource(database: database);

    await datasource.ensureSeeded();

    final barcodeResult = await datasource.searchVariants(
      query: '789100000020',
    );
    final skuResult = await datasource.searchVariants(query: 'JEA-SLI-40');

    expect(barcodeResult.single.displayName, 'Bolsa Couro Eco Caramelo');
    expect(skuResult.single.size, '40');
  });
}
