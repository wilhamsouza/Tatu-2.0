import '../../domain/entities/category_sale_snapshot.dart';
import '../../domain/entities/product_variant_sale_snapshot.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/local/catalog_local_datasource.dart';

class LocalCatalogRepository implements CatalogRepository {
  const LocalCatalogRepository({
    required CatalogLocalDatasource localDatasource,
  }) : _localDatasource = localDatasource;

  final CatalogLocalDatasource _localDatasource;

  @override
  Future<void> ensureSeeded() {
    return _localDatasource.ensureSeeded();
  }

  @override
  Future<List<CategorySaleSnapshot>> listCategories() {
    return _localDatasource.listCategories();
  }

  @override
  Future<List<ProductVariantSaleSnapshot>> searchVariants({
    String query = '',
    String? categoryName,
  }) {
    return _localDatasource.searchVariants(
      query: query,
      categoryName: categoryName,
    );
  }
}
