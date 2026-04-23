import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.tone = AppTone.neutral,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tatuzinTokens;
    final colors = tokens.tone(tone);
    final isNeutral = tone == AppTone.neutral;

    return Card(
      color: isNeutral ? tokens.surfaceRaised : colors.background,
      child: Padding(
        padding: tokens.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: isNeutral
                                  ? Theme.of(context).colorScheme.onSurface
                                  : colors.foreground,
                            ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: TatuzinSpacing.xs),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isNeutral
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : colors.foreground.withValues(alpha: 0.92),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(width: TatuzinSpacing.sm),
                  action!,
                ],
              ],
            ),
            const SizedBox(height: TatuzinSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
