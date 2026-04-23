import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../domain/entities/erp_entities.dart';
import '../../domain/repositories/erp_repository.dart';
import '../../presentation/providers/erp_providers.dart';

final erpOverviewNotifierProvider =
    AsyncNotifierProvider<ErpOverviewNotifier, ErpOverview>(
      ErpOverviewNotifier.new,
    );

class ErpOverviewNotifier extends AsyncNotifier<ErpOverview> {
  ErpRepository get _repository => ref.read(erpRepositoryProvider);

  @override
  Future<ErpOverview> build() async {
    ref.watch(sessionNotifierProvider);
    return _loadOverview();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadOverview);
  }

  Future<void> createCategory({
    required String name,
    required bool active,
  }) async {
    await _mutate((accessToken) {
      return _repository.createCategory(
        accessToken: accessToken,
        name: name,
        active: active,
      );
    });
  }

  Future<void> createProduct({
    required String name,
    String? categoryId,
    required bool active,
  }) async {
    await _mutate((accessToken) {
      return _repository.createProduct(
        accessToken: accessToken,
        name: name,
        categoryId: categoryId,
        active: active,
      );
    });
  }

  Future<void> updateProduct({
    required String productId,
    String? name,
    String? categoryId,
    bool? active,
  }) async {
    await _mutate((accessToken) {
      return _repository.updateProduct(
        accessToken: accessToken,
        productId: productId,
        name: name,
        categoryId: categoryId,
        active: active,
      );
    });
  }

  Future<void> createVariant({
    required String productId,
    String? barcode,
    String? sku,
    String? color,
    String? size,
    required int priceInCents,
    int? promotionalPriceInCents,
    required bool active,
  }) async {
    await _mutate((accessToken) {
      return _repository.createVariant(
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
    });
  }

  Future<void> updateVariant({
    required String variantId,
    String? barcode,
    String? sku,
    String? color,
    String? size,
    int? priceInCents,
    int? promotionalPriceInCents,
    bool? active,
  }) async {
    await _mutate((accessToken) {
      return _repository.updateVariant(
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
    });
  }

  Future<void> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    await _mutate((accessToken) {
      return _repository.createSupplier(
        accessToken: accessToken,
        name: name,
        phone: phone,
        email: email,
        notes: notes,
      );
    });
  }

  Future<void> createPurchase({
    required String supplierId,
    String? notes,
    required List<ErpPurchaseDraftItem> items,
  }) async {
    await _mutate((accessToken) {
      return _repository.createPurchase(
        accessToken: accessToken,
        supplierId: supplierId,
        notes: notes,
        items: items,
      );
    });
  }

  Future<void> receivePurchase({
    required String purchaseId,
    required List<ErpPurchaseReceiptDraftItem> items,
  }) async {
    await _mutate((accessToken) {
      return _repository.receivePurchase(
        accessToken: accessToken,
        purchaseId: purchaseId,
        items: items,
      );
    });
  }

  Future<void> createInventoryAdjustment({
    required String variantId,
    required int quantityDelta,
    String? reason,
  }) async {
    await _mutate((accessToken) {
      return _repository.createInventoryAdjustment(
        accessToken: accessToken,
        variantId: variantId,
        quantityDelta: quantityDelta,
        reason: reason,
      );
    });
  }

  Future<void> recordInventoryCount({
    required List<ErpInventoryCountDraftItem> items,
  }) async {
    await _mutate((accessToken) {
      return _repository.recordInventoryCount(
        accessToken: accessToken,
        items: items,
      );
    });
  }

  Future<void> settleReceivable({
    required String receivableId,
    required int amountInCents,
    required String settlementMethod,
  }) async {
    await _mutate((accessToken) {
      return _repository.settleReceivable(
        accessToken: accessToken,
        receivableId: receivableId,
        amountInCents: amountInCents,
        settlementMethod: settlementMethod,
      );
    });
  }

  Future<ErpOverview> _loadOverview() async {
    final accessToken = _currentAccessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return const ErpOverview.empty();
    }

    return _repository.loadOverview(accessToken: accessToken);
  }

  Future<void> _mutate(
    Future<Object?> Function(String accessToken) action,
  ) async {
    final accessToken = _currentAccessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ErpOverviewException('Sessao invalida para operar o ERP.');
    }

    final previous = state.asData?.value;

    try {
      await action(accessToken);
      final overview = await _repository.loadOverview(accessToken: accessToken);
      state = AsyncData(overview);
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  String? get _currentAccessToken =>
      ref.read(sessionNotifierProvider).asData?.value?.tokens.accessToken;
}

class ErpOverviewException implements Exception {
  const ErpOverviewException(this.message);

  final String message;

  @override
  String toString() => message;
}
