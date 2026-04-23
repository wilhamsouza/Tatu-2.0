import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppTone.neutral,
  });

  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tatuzinTokens;
    final colors = tokens.tone(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TatuzinSpacing.sm,
          vertical: TatuzinSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.foreground,
          ),
        ),
      ),
    );
  }
}
