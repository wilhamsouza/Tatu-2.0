import '../../domain/entities/category_sale_snapshot.dart';
import '../../domain/entities/product_variant_sale_snapshot.dart';
import '../../domain/repositories/catalog_repository.dart';

class LoadSaleCatalogUseCase {
  const LoadSaleCatalogUseCase(this._repository);

  final CatalogRepository _repository;

  Future<SaleCatalogView> call({
    String query = '',
    String? categoryName,
  }) async {
    await _repository.ensureSeeded();
    final categories = await _repository.listCategories();
    final variants = await _repository.searchVariants(
      query: query,
      categoryName: categoryName,
    );
    return SaleCatalogView(categories: categories, variants: variants);
  }
}

class SaleCatalogView {
  const SaleCatalogView({required this.categories, required this.variants});

  final List<CategorySaleSnapshot> categories;
  final List<ProductVariantSaleSnapshot> variants;
}
