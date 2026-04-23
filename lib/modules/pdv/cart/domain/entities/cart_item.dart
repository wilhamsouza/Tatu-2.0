import '../../../catalog/domain/entities/product_variant_sale_snapshot.dart';

class CartItem {
  const CartItem({required this.variant, required this.quantity});

  final ProductVariantSaleSnapshot variant;
  final int quantity;

  int get unitPriceInCents => variant.effectivePriceInCents;
  int get totalPriceInCents => unitPriceInCents * quantity;

  CartItem copyWith({ProductVariantSaleSnapshot? variant, int? quantity}) {
    return CartItem(
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'variant': <String, Object?>{
        'localId': variant.localId,
        'remoteId': variant.remoteId,
        'productRemoteId': variant.productRemoteId,
        'barcode': variant.barcode,
        'sku': variant.sku,
        'displayName': variant.displayName,
        'shortName': variant.shortName,
        'color': variant.color,
        'size': variant.size,
        'categoryName': variant.categoryName,
        'priceInCents': variant.priceInCents,
        'promotionalPriceInCents': variant.promotionalPriceInCents,
        'imageUrl': variant.imageUrl,
        'imageLocalPath': variant.imageLocalPath,
        'isActiveForSale': variant.isActiveForSale,
        'updatedAt': variant.updatedAt.toIso8601String(),
      },
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final variant = json['variant']! as Map<String, dynamic>;
    return CartItem(
      variant: ProductVariantSaleSnapshot(
        localId: (variant['localId']! as num).toInt(),
        remoteId: variant['remoteId'] as String?,
        productRemoteId: variant['productRemoteId'] as String?,
        barcode: variant['barcode'] as String?,
        sku: variant['sku'] as String?,
        displayName: variant['displayName']! as String,
        shortName: variant['shortName'] as String?,
        color: variant['color'] as String?,
        size: variant['size'] as String?,
        categoryName: variant['categoryName'] as String?,
        priceInCents: (variant['priceInCents']! as num).toInt(),
        promotionalPriceInCents: (variant['promotionalPriceInCents'] as num?)
            ?.toInt(),
        imageUrl: variant['imageUrl'] as String?,
        imageLocalPath: variant['imageLocalPath'] as String?,
        isActiveForSale: variant['isActiveForSale']! as bool,
        updatedAt: DateTime.parse(variant['updatedAt']! as String),
      ),
      quantity: (json['quantity']! as num).toInt(),
    );
  }
}
