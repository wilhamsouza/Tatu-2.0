import '../entities/category_sale_snapshot.dart';
import '../entities/product_variant_sale_snapshot.dart';

abstract class CatalogRepository {
  Future<void> ensureSeeded();

  Future<List<CategorySaleSnapshot>> listCategories();

  Future<List<ProductVariantSaleSnapshot>> searchVariants({
    String query = '',
    String? categoryName,
  });
}
