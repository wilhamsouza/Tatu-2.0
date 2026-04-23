import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.tone = AppTone.neutral,
  });

  final String label;
  final String value;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tatuzinTokens;
    final colors = tokens.tone(tone);
    final isNeutral = tone == AppTone.neutral;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isNeutral ? tokens.surfaceSunken : colors.background,
        borderRadius: BorderRadius.circular(tokens.panelRadius),
        border: Border.all(color: isNeutral ? tokens.borderSoft : colors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tokens.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TatuzinSpacing.md,
          vertical: TatuzinSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isNeutral
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : colors.foreground.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: TatuzinSpacing.xxs),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isNeutral
                    ? Theme.of(context).colorScheme.onSurface
                    : colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
