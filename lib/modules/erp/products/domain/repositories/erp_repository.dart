import '../entities/erp_entities.dart';

class ErpPurchaseDraftItem {
  const ErpPurchaseDraftItem({
    required this.variantId,
    required this.quantityOrdered,
    required this.unitCostInCents,
  });

  final String variantId;
  final int quantityOrdered;
  final int unitCostInCents;
}

class ErpPurchaseReceiptDraftItem {
  const ErpPurchaseReceiptDraftItem({
    required this.purchaseItemId,
    required this.quantityReceived,
  });

  final String purchaseItemId;
  final int quantityReceived;
}

class ErpInventoryCountDraftItem {
  const ErpInventoryCountDraftItem({
    required this.variantId,
    required this.countedQuantity,
  });

  final String variantId;
  final int countedQuantity;
}

abstract class ErpRepository {
  Future<ErpOverview> loadOverview({required String accessToken});

  Future<ErpReportsDashboard> loadReportsDashboard({
    required String accessToken,
  });

  Future<ErpCategory> createCategory({
    required String accessToken,
    required String name,
    required bool active,
  });

  Future<ErpCategory> updateCategory({
    required String accessToken,
    required String categoryId,
    String? name,
    bool? active,
  });

  Future<ErpProduct> createProduct({
    required String accessToken,
    required String name,
    String? categoryId,
    required bool active,
  });

  Future<ErpProduct> updateProduct({
    required String accessToken,
    required String productId,
    String? name,
    String? categoryId,
    bool? active,
  });

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
  });

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
  });

  Future<ErpSupplier> createSupplier({
    required String accessToken,
    required String name,
    String? phone,
    String? email,
    String? notes,
  });

  Future<ErpPurchase> createPurchase({
    required String accessToken,
    required String supplierId,
    String? notes,
    required List<ErpPurchaseDraftItem> items,
  });

  Future<ErpPurchase> receivePurchase({
    required String accessToken,
    required String purchaseId,
    String? receivedAtIso,
    required List<ErpPurchaseReceiptDraftItem> items,
  });

  Future<void> createInventoryAdjustment({
    required String accessToken,
    required String variantId,
    required int quantityDelta,
    String? reason,
  });

  Future<void> recordInventoryCount({
    required String accessToken,
    required List<ErpInventoryCountDraftItem> items,
  });

  Future<void> settleReceivable({
    required String accessToken,
    required String receivableId,
    required int amountInCents,
    required String settlementMethod,
  });
}
