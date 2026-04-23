import 'applied_discount.dart';
import 'cart_item.dart';

class Cart {
  const Cart({required this.items, this.discount});

  const Cart.empty() : items = const <CartItem>[], discount = null;

  final List<CartItem> items;
  final AppliedDiscount? discount;

  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);
  int get subtotalInCents =>
      items.fold<int>(0, (sum, item) => sum + item.totalPriceInCents);
  int get discountInCents =>
      discount?.resolveAmountInCents(subtotalInCents) ?? 0;
  int get totalInCents =>
      (subtotalInCents - discountInCents).clamp(0, subtotalInCents);
  bool get isEmpty => items.isEmpty;

  Cart add(CartItem nextItem) {
    final index = items.indexWhere(
      (item) => item.variant.localId == nextItem.variant.localId,
    );
    if (index == -1) {
      return copyWith(items: <CartItem>[...items, nextItem]);
    }

    final updated = <CartItem>[...items];
    final current = updated[index];
    updated[index] = current.copyWith(
      quantity: current.quantity + nextItem.quantity,
    );
    return copyWith(items: updated);
  }

  Cart updateQuantity({required int variantLocalId, required int quantity}) {
    if (quantity <= 0) {
      return remove(variantLocalId);
    }

    return copyWith(
      items: items
          .map(
            (item) => item.variant.localId == variantLocalId
                ? item.copyWith(quantity: quantity)
                : item,
          )
          .toList(),
    );
  }

  Cart remove(int variantLocalId) {
    return copyWith(
      items: items
          .where((item) => item.variant.localId != variantLocalId)
          .toList(),
    );
  }

  Cart clear() => const Cart.empty();

  Cart applyDiscount(AppliedDiscount? nextDiscount) {
    return copyWith(discount: nextDiscount);
  }

  Cart copyWith({
    List<CartItem>? items,
    AppliedDiscount? discount,
    bool clearDiscount = false,
  }) {
    return Cart(
      items: items ?? this.items,
      discount: clearDiscount ? null : discount ?? this.discount,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'items': items.map((item) => item.toJson()).toList(),
      'discount': discount?.toJson(),
    };
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const <dynamic>[]);
    return Cart(
      items: rawItems
          .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      discount: json['discount'] == null
          ? null
          : AppliedDiscount.fromJson(json['discount']! as Map<String, dynamic>),
    );
  }
}
