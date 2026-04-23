class CategorySaleSnapshot {
  const CategorySaleSnapshot({
    required this.localId,
    this.remoteId,
    required this.name,
    required this.updatedAt,
  });

  final int localId;
  final String? remoteId;
  final String name;
  final DateTime updatedAt;
}
