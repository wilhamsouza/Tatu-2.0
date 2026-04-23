class ProductSaleSnapshot {
  const ProductSaleSnapshot({
    required this.localId,
    this.remoteId,
    required this.name,
    this.categoryName,
    required this.isActive,
    required this.updatedAt,
  });

  final int localId;
  final String? remoteId;
  final String name;
  final String? categoryName;
  final bool isActive;
  final DateTime updatedAt;
}
