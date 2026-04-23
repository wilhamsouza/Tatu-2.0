import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers/database_providers.dart';
import '../../application/usecases/load_sale_catalog_usecase.dart';
import '../../data/datasources/local/catalog_local_datasource.dart';
import '../../data/repositories/local_catalog_repository.dart';
import '../../domain/repositories/catalog_repository.dart';

final catalogLocalDatasourceProvider = Provider<CatalogLocalDatasource>((ref) {
  return CatalogLocalDatasource(database: ref.read(appDatabaseProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return LocalCatalogRepository(
    localDatasource: ref.read(catalogLocalDatasourceProvider),
  );
});

final loadSaleCatalogUseCaseProvider = Provider<LoadSaleCatalogUseCase>((ref) {
  return LoadSaleCatalogUseCase(ref.read(catalogRepositoryProvider));
});

class CatalogFilter {
  const CatalogFilter({this.query = '', this.categoryName});

  final String query;
  final String? categoryName;

  @override
  bool operator ==(Object other) {
    return other is CatalogFilter &&
        other.query == query &&
        other.categoryName == categoryName;
  }

  @override
  int get hashCode => Object.hash(query, categoryName);
}

final saleCatalogProvider =
    FutureProvider.family<SaleCatalogView, CatalogFilter>((ref, filter) async {
      return ref
          .read(loadSaleCatalogUseCaseProvider)
          .call(query: filter.query, categoryName: filter.categoryName);
    });
