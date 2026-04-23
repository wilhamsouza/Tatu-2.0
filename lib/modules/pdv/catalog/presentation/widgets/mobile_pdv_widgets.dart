import 'package:flutter/material.dart';

import '../../../../../core/ui/theme/app_theme_tokens.dart';
import '../../../../../core/utils/currency_utils.dart';
import '../../domain/entities/product_variant_sale_snapshot.dart';

class PdvBottomSheetHandle extends StatelessWidget {
  const PdvBottomSheetHandle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

class PdvMobileCartBar extends StatelessWidget {
  const PdvMobileCartBar({
    super.key,
    required this.totalItems,
    required this.totalInCents,
    required this.checkoutBlocked,
    required this.isLoading,
    required this.onOpen,
  });

  final int totalItems;
  final int totalInCents;
  final bool checkoutBlocked;
  final bool isLoading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasItems = totalItems > 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          elevation: 8,
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: hasItems
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: hasItems
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    child: Text('$totalItems'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          hasItems ? 'Carrinho pronto' : 'Carrinho vazio',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          hasItems
                              ? CurrencyUtils.formatMoney(totalInCents)
                              : 'Toque para revisar checkout',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shopping_cart_checkout_outlined),
                    label: Text(checkoutBlocked ? 'Abrir' : 'Checkout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PdvMobileProductTile extends StatelessWidget {
  const PdvMobileProductTile({
    super.key,
    required this.variant,
    required this.onAdd,
  });

  final ProductVariantSaleSnapshot variant;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tatuzinTokens;
    final effectivePriceInCents = variant.effectivePriceInCents;
    final priceInCents = variant.priceInCents;
    final hasPromotion = effectivePriceInCents != priceInCents;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    variant.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variant.subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      variant.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (variant.categoryName != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      variant.categoryName!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: <Widget>[
                      if (hasPromotion)
                        Text(
                          CurrencyUtils.formatMoney(priceInCents),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                decoration: TextDecoration.lineThrough,
                              ),
                        ),
                      Text(
                        CurrencyUtils.formatMoney(effectivePriceInCents),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: tokens.tone(AppTone.cash).foreground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                minimumSize: const Size(92, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}
