import 'package:uuid/uuid.dart';

import '../../../../../../core/database/app_database.dart';
import '../../../domain/entities/category_sale_snapshot.dart';
import '../../../domain/entities/product_variant_sale_snapshot.dart';

class CatalogLocalDatasource {
  CatalogLocalDatasource({required AppDatabase database, Uuid? uuid})
    : _database = database,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<void> ensureSeeded() async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM product_variants_snapshot',
    );
    final total = (result.first['total'] as int?) ?? 0;
    if (total > 0) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final categories = <Map<String, Object?>>[
        <String, Object?>{
          'remote_id': 'category_basicos',
          'name': 'Basicos',
          'updated_at': now,
        },
        <String, Object?>{
          'remote_id': 'category_jeans',
          'name': 'Jeans',
          'updated_at': now,
        },
        <String, Object?>{
          'remote_id': 'category_acessorios',
          'name': 'Acessorios',
          'updated_at': now,
        },
      ];

      for (final category in categories) {
        await txn.insert('categories_snapshot', category);
      }

      final products = <Map<String, Object?>>[
        <String, Object?>{
          'remote_id': 'product_cam_basica',
          'name': 'Camiseta Basica',
          'category_name': 'Basicos',
          'is_active': 1,
          'updated_at': now,
        },
        <String, Object?>{
          'remote_id': 'product_jeans_slim',
          'name': 'Calca Jeans Slim',
          'category_name': 'Jeans',
          'is_active': 1,
          'updated_at': now,
        },
        <String, Object?>{
          'remote_id': 'product_bolsa_couro',
          'name': 'Bolsa Couro Eco',
          'category_name': 'Acessorios',
          'is_active': 1,
          'updated_at': now,
        },
      ];

      for (final product in products) {
        await txn.insert('products_snapshot', product);
      }

      final variants = <Map<String, Object?>>[
        _variantRow(
          remoteId: 'variant_cam_preta_p',
          productRemoteId: 'product_cam_basica',
          barcode: '789100000001',
          sku: 'CAM-PRE-P',
          displayName: 'Camiseta Basica Preta',
          shortName: 'Camiseta Preta',
          color: 'Preto',
          size: 'P',
          categoryName: 'Basicos',
          priceInCents: 5990,
          promotionalPriceInCents: 4990,
          updatedAt: now,
        ),
        _variantRow(
          remoteId: 'variant_cam_preta_m',
          productRemoteId: 'product_cam_basica',
          barcode: '789100000002',
          sku: 'CAM-PRE-M',
          displayName: 'Camiseta Basica Preta',
          shortName: 'Camiseta Preta',
          color: 'Preto',
          size: 'M',
          categoryName: 'Basicos',
          priceInCents: 5990,
          promotionalPriceInCents: 4990,
          updatedAt: now,
        ),
        _variantRow(
          remoteId: 'variant_cam_branca_g',
          productRemoteId: 'product_cam_basica',
          barcode: '789100000003',
          sku: 'CAM-BRA-G',
          displayName: 'Camiseta Basica Branca',
          shortName: 'Camiseta Branca',
          color: 'Branco',
          size: 'G',
          categoryName: 'Basicos',
          priceInCents: 5990,
          updatedAt: now,
        ),
        _variantRow(
          remoteId: 'variant_jeans_38',
          productRemoteId: 'product_jeans_slim',
          barcode: '789100000010',
          sku: 'JEA-SLI-38',
          displayName: 'Calca Jeans Slim Azul',
          shortName: 'Jeans Slim',
          color: 'Azul',
          size: '38',
          categoryName: 'Jeans',
          priceInCents: 15990,
          updatedAt: now,
        ),
        _variantRow(
          remoteId: 'variant_jeans_40',
          productRemoteId: 'product_jeans_slim',
          barcode: '789100000011',
          sku: 'JEA-SLI-40',
          displayName: 'Calca Jeans Slim Azul',
          shortName: 'Jeans Slim',
          color: 'Azul',
          size: '40',
          categoryName: 'Jeans',
          priceInCents: 15990,
          promotionalPriceInCents: 14990,
          updatedAt: now,
        ),
        _variantRow(
          remoteId: 'variant_bolsa_unica',
          productRemoteId: 'product_bolsa_couro',
          barcode: '789100000020',
          sku: 'BOL-ECO-U',
          displayName: 'Bolsa Couro Eco Caramelo',
          shortName: 'Bolsa Eco',
          color: 'Caramelo',
          size: 'Unico',
          categoryName: 'Acessorios',
          priceInCents: 18990,
          updatedAt: now,
        ),
      ];

      for (final variant in variants) {
        await txn.insert('product_variants_snapshot', variant);
      }
    });
  }

  Future<List<CategorySaleSnapshot>> listCategories() async {
    final db = await _database.database;
    final rows = await db.query('categories_snapshot', orderBy: 'name ASC');
    return rows.map(_mapCategory).toList();
  }

  Future<List<ProductVariantSaleSnapshot>> searchVariants({
    String query = '',
    String? categoryName,
  }) async {
    final db = await _database.database;
    final buffer = StringBuffer('is_active_for_sale = 1');
    final whereArgs = <Object?>[];
    final normalizedQuery = query.trim();

    if (normalizedQuery.isNotEmpty) {
      buffer.write(
        ' AND (display_name LIKE ? OR short_name LIKE ? OR barcode LIKE ? OR sku LIKE ?)',
      );
      final likeValue = '%$normalizedQuery%';
      whereArgs.addAll(<Object?>[likeValue, likeValue, likeValue, likeValue]);
    }

    if (categoryName != null && categoryName.trim().isNotEmpty) {
      buffer.write(' AND category_name = ?');
      whereArgs.add(categoryName.trim());
    }

    final rows = await db.query(
      'product_variants_snapshot',
      where: buffer.toString(),
      whereArgs: whereArgs,
      orderBy: 'display_name ASC, color ASC, size ASC',
    );

    return rows.map(_mapVariant).toList();
  }

  Map<String, Object?> _variantRow({
    required String remoteId,
    required String productRemoteId,
    required String barcode,
    required String sku,
    required String displayName,
    required String shortName,
    required String color,
    required String size,
    required String categoryName,
    required int priceInCents,
    int? promotionalPriceInCents,
    required String updatedAt,
  }) {
    return <String, Object?>{
      'remote_id': remoteId,
      'product_remote_id': productRemoteId,
      'barcode': barcode,
      'sku': sku,
      'display_name': displayName,
      'short_name': shortName,
      'color': color,
      'size': size,
      'category_name': categoryName,
      'price_cents': priceInCents,
      'promotional_price_cents': promotionalPriceInCents,
      'image_url': 'https://tatuzin.local/assets/${_uuid.v4()}.png',
      'image_local_path': null,
      'is_active_for_sale': 1,
      'updated_at': updatedAt,
    };
  }

  CategorySaleSnapshot _mapCategory(Map<String, Object?> row) {
    return CategorySaleSnapshot(
      localId: row['local_id']! as int,
      remoteId: row['remote_id'] as String?,
      name: row['name']! as String,
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }

  ProductVariantSaleSnapshot _mapVariant(Map<String, Object?> row) {
    return ProductVariantSaleSnapshot(
      localId: row['local_id']! as int,
      remoteId: row['remote_id'] as String?,
      productRemoteId: row['product_remote_id'] as String?,
      barcode: row['barcode'] as String?,
      sku: row['sku'] as String?,
      displayName: row['display_name']! as String,
      shortName: row['short_name'] as String?,
      color: row['color'] as String?,
      size: row['size'] as String?,
      categoryName: row['category_name'] as String?,
      priceInCents: row['price_cents']! as int,
      promotionalPriceInCents: row['promotional_price_cents'] as int?,
      imageUrl: row['image_url'] as String?,
      imageLocalPath: row['image_local_path'] as String?,
      isActiveForSale: (row['is_active_for_sale']! as int) == 1,
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}
