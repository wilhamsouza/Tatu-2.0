class ProductVariantSaleSnapshot {
  const ProductVariantSaleSnapshot({
    required this.localId,
    this.remoteId,
    this.productRemoteId,
    this.barcode,
    this.sku,
    required this.displayName,
    this.shortName,
    this.color,
    this.size,
    this.categoryName,
    required this.priceInCents,
    this.promotionalPriceInCents,
    this.imageUrl,
    this.imageLocalPath,
    required this.isActiveForSale,
    required this.updatedAt,
  });

  final int localId;
  final String? remoteId;
  final String? productRemoteId;
  final String? barcode;
  final String? sku;
  final String displayName;
  final String? shortName;
  final String? color;
  final String? size;
  final String? categoryName;
  final int priceInCents;
  final int? promotionalPriceInCents;
  final String? imageUrl;
  final String? imageLocalPath;
  final bool isActiveForSale;
  final DateTime updatedAt;

  int get effectivePriceInCents => promotionalPriceInCents ?? priceInCents;

  String get subtitle {
    final values = <String>[
      if (color != null && color!.trim().isNotEmpty) color!,
      if (size != null && size!.trim().isNotEmpty) size!,
    ];
    return values.join(' / ');
  }
}
