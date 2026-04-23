class LocalSaleItem {
  const LocalSaleItem({
    required this.localId,
    required this.saleLocalId,
    this.variantLocalId,
    this.variantRemoteId,
    required this.displayName,
    required this.quantity,
    required this.unitPriceInCents,
    required this.totalPriceInCents,
    required this.discountInCents,
    required this.createdAt,
  });

  final String localId;
  final String saleLocalId;
  final int? variantLocalId;
  final String? variantRemoteId;
  final String displayName;
  final int quantity;
  final int unitPriceInCents;
  final int totalPriceInCents;
  final int discountInCents;
  final DateTime createdAt;
}
