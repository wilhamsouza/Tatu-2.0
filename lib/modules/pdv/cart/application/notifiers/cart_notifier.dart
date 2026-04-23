import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers/database_providers.dart';
import '../../../catalog/domain/entities/product_variant_sale_snapshot.dart';
import '../../domain/entities/applied_discount.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/cart_item.dart';

const _cartDraftSettingKey = 'pdv.cart_draft';

final cartNotifierProvider = NotifierProvider<CartNotifier, Cart>(
  CartNotifier.new,
);

class CartNotifier extends Notifier<Cart> {
  @override
  Cart build() {
    _restore();
    return const Cart.empty();
  }

  void addVariant(ProductVariantSaleSnapshot variant) {
    state = state.add(CartItem(variant: variant, quantity: 1));
    _persist();
  }

  void incrementItem(int variantLocalId) {
    final item = state.items.firstWhere(
      (entry) => entry.variant.localId == variantLocalId,
    );
    state = state.updateQuantity(
      variantLocalId: variantLocalId,
      quantity: item.quantity + 1,
    );
    _persist();
  }

  void decrementItem(int variantLocalId) {
    final item = state.items.firstWhere(
      (entry) => entry.variant.localId == variantLocalId,
    );
    state = state.updateQuantity(
      variantLocalId: variantLocalId,
      quantity: item.quantity - 1,
    );
    _persist();
  }

  void removeItem(int variantLocalId) {
    state = state.remove(variantLocalId);
    _persist();
  }

  void applyDiscount(AppliedDiscount? discount) {
    state = state.applyDiscount(discount);
    _persist();
  }

  void clear() {
    state = const Cart.empty();
    _persist();
  }

  Future<void> _restore() async {
    final rawValue = await ref
        .read(appDatabaseProvider)
        .loadAppSetting(_cartDraftSettingKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(rawValue) as Map<String, dynamic>;
    state = Cart.fromJson(decoded);
  }

  Future<void> _persist() async {
    if (state.isEmpty && state.discount == null) {
      await ref
          .read(appDatabaseProvider)
          .deleteAppSetting(_cartDraftSettingKey);
      return;
    }

    await ref
        .read(appDatabaseProvider)
        .saveAppSetting(
          key: _cartDraftSettingKey,
          value: jsonEncode(state.toJson()),
        );
  }
}
