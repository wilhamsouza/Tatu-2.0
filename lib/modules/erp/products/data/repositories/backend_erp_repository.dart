import '../../domain/entities/erp_entities.dart';
import '../../domain/repositories/erp_repository.dart';
import '../datasources/remote/erp_remote_datasource.dart';

class BackendErpRepository implements ErpRepository {
  const BackendErpRepository({required ErpRemoteDatasource remoteDatasource})
    : _remoteDatasource = remoteDatasource;

  final ErpRemoteDatasource _remoteDatasource;

  @override
  Future<ErpOverview> loadOverview({required String accessToken}) async {
    final categoriesFuture = _remoteDatasource.fetchCategories(
      accessToken: accessToken,
    );
    final productsFuture = _remoteDatasource.fetchProducts(
      accessToken: accessToken,
    );
    final variantsFuture = _remoteDatasource.fetchVariants(
      accessToken: accessToken,
    );
    final inventoryFuture = _remoteDatasource.fetchInventorySummary(
      accessToken: accessToken,
    );
    final suppliersFuture = _remoteDatasource.fetchSuppliers(
      accessToken: accessToken,
    );
    final purchasesFuture = _remoteDatasource.fetchPurchases(
      accessToken: accessToken,
    );
    final receivablesFuture = _remoteDatasource.fetchReceivables(
      accessToken: accessToken,
    );
    final cashSessionsFuture = _remoteDatasource.fetchCashSessions(
      accessToken: accessToken,
    );

    final categories = await categoriesFuture;
    final products = await productsFuture;
    final variants = await variantsFuture;
    final inventoryItems = await inventoryFuture;
    final suppliers = await suppliersFuture;
    final purchases = await purchasesFuture;
    final receivables = await receivablesFuture;
    final cashSessions = await cashSessionsFuture;

    return ErpOverview(
      categories: categories.map(ErpCategory.fromJson).toList(),
      products: products.map(ErpProduct.fromJson).toList(),
      variants: variants.map(ErpVariant.fromJson).toList(),
      inventoryItems: inventoryItems.map(ErpInventoryItem.fromJson).toList(),
      suppliers: suppliers.map(ErpSupplier.fromJson).toList(),
      purchases: purchases.map(ErpPurchase.fromJson).toList(),
      receivables: receivables.map(ErpReceivableNote.fromJson).toList(),
      cashSessions: cashSessions.map(ErpCashSession.fromJson).toList(),
    );
  }

  @override
  Future<ErpReportsDashboard> loadReportsDashboard({
    required String accessToken,
  }) async {
    final response = await _remoteDatasource.fetchReportsDashboard(
      accessToken: accessToken,
    );
    return ErpReportsDashboard.fromJson(response);
  }

  @override
  Future<ErpCategory> createCategory({
    required String accessToken,
    required String name,
    required bool active,
  }) async {
    final response = await _remoteDatasource.createCategory(
      accessToken: accessToken,
      name: name,
      active: active,
    );
    return ErpCategory.fromJson(response);
  }

  @override
  Future<ErpCategory> updateCategory({
    required String accessToken,
    required String categoryId,
    String? name,
    bool? active,
  }) async {
    final response = await _remoteDatasource.updateCategory(
      accessToken: accessToken,
      categoryId: categoryId,
      name: name,
      active: active,
    );
    return ErpCategory.fromJson(response);
  }

  @override
  Future<ErpProduct> createProduct({
    required String accessToken,
    required String name,
    String? categoryId,
    required bool active,
  }) async {
    final response = await _remoteDatasource.createProduct(
      accessToken: accessToken,
      name: name,
      categoryId: categoryId,
      active: active,
    );
    return ErpProduct.fromJson(response);
  }

  @override
  Future<ErpProduct> updateProduct({
    required String accessToken,
    required String productId,
    String? name,
    String? categoryId,
    bool? active,
  }) async {
    final response = await _remoteDatasource.updateProduct(
      accessToken: accessToken,
      productId: productId,
      name: name,
      categoryId: categoryId,
      active: active,
    );
    return ErpProduct.fromJson(response);
  }

  @override
  Future<ErpVariant> createVariant({
    required String accessToken,
    required String productId,
    String? barcode,
    String? sku,
    String? color,
    String? size,
    required int priceInCents,
    int? promotionalPriceInCents,
    required bool active,
  }) async {
    final response = await _remoteDatasource.createVariant(
      accessToken: accessToken,
      productId: productId,
      barcode: barcode,
      sku: sku,
      color: color,
      size: size,
      priceInCents: priceInCents,
      promotionalPriceInCents: promotionalPriceInCents,
      active: active,
    );
    return ErpVariant.fromJson(response);
  }

  @override
  Future<ErpVariant> updateVariant({
    required String accessToken,
    required String variantId,
    String? barcode,
    String? sku,
    String? color,
    String? size,
    int? priceInCents,
    int? promotionalPriceInCents,
    bool? active,
  }) async {
    final response = await _remoteDatasource.updateVariant(
      accessToken: accessToken,
      variantId: variantId,
      barcode: barcode,
      sku: sku,
      color: color,
      size: size,
      priceInCents: priceInCents,
      promotionalPriceInCents: promotionalPriceInCents,
      active: active,
    );
    return ErpVariant.fromJson(response);
  }

  @override
  Future<ErpSupplier> createSupplier({
    required String accessToken,
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    final response = await _remoteDatasource.createSupplier(
      accessToken: accessToken,
      name: name,
      phone: phone,
      email: email,
      notes: notes,
    );
    return ErpSupplier.fromJson(response);
  }

  @override
  Future<ErpPurchase> createPurchase({
    required String accessToken,
    required String supplierId,
    String? notes,
    required List<ErpPurchaseDraftItem> items,
  }) async {
    final response = await _remoteDatasource.createPurchase(
      accessToken: accessToken,
      supplierId: supplierId,
      notes: notes,
      items: items
          .map(
            (item) => <String, dynamic>{
              'variantId': item.variantId,
              'quantityOrdered': item.quantityOrdered,
              'unitCostInCents': item.unitCostInCents,
            },
          )
          .toList(),
    );
    return ErpPurchase.fromJson(response);
  }

  @override
  Future<ErpPurchase> receivePurchase({
    required String accessToken,
    required String purchaseId,
    String? receivedAtIso,
    required List<ErpPurchaseReceiptDraftItem> items,
  }) async {
    final response = await _remoteDatasource.receivePurchase(
      accessToken: accessToken,
      purchaseId: purchaseId,
      receivedAtIso: receivedAtIso,
      items: items
          .map(
            (item) => <String, dynamic>{
              'purchaseItemId': item.purchaseItemId,
              'quantityReceived': item.quantityReceived,
            },
          )
          .toList(),
    );
    return ErpPurchase.fromJson(response);
  }

  @override
  Future<void> createInventoryAdjustment({
    required String accessToken,
    required String variantId,
    required int quantityDelta,
    String? reason,
  }) async {
    await _remoteDatasource.createInventoryAdjustment(
      accessToken: accessToken,
      variantId: variantId,
      quantityDelta: quantityDelta,
      reason: reason,
    );
  }

  @override
  Future<void> recordInventoryCount({
    required String accessToken,
    required List<ErpInventoryCountDraftItem> items,
  }) async {
    await _remoteDatasource.recordInventoryCount(
      accessToken: accessToken,
      items: items
          .map(
            (item) => <String, dynamic>{
              'variantId': item.variantId,
              'countedQuantity': item.countedQuantity,
            },
          )
          .toList(),
    );
  }

  @override
  Future<void> settleReceivable({
    required String accessToken,
    required String receivableId,
    required int amountInCents,
    required String settlementMethod,
  }) async {
    await _remoteDatasource.settleReceivable(
      accessToken: accessToken,
      receivableId: receivableId,
      amountInCents: amountInCents,
      settlementMethod: settlementMethod,
    );
  }
}
