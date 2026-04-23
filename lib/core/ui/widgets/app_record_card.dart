import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

class AppRecordCard extends StatelessWidget {
  const AppRecordCard({
    super.key,
    required this.title,
    required this.lines,
    this.badge,
    this.actions = const <Widget>[],
    this.tone = AppTone.neutral,
  });

  final String title;
  final List<String> lines;
  final Widget? badge;
  final List<Widget> actions;
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
      ),
      child: Padding(
        padding: const EdgeInsets.all(TatuzinSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isNeutral
                          ? Theme.of(context).colorScheme.onSurface
                          : colors.foreground,
                    ),
                  ),
                ),
                if (badge != null) ...<Widget>[
                  const SizedBox(width: TatuzinSpacing.sm),
                  badge!,
                ],
              ],
            ),
            const SizedBox(height: TatuzinSpacing.sm),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: TatuzinSpacing.xxs),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isNeutral
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : colors.foreground.withValues(alpha: 0.92),
                  ),
                ),
              ),
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: TatuzinSpacing.sm),
              Wrap(
                spacing: TatuzinSpacing.xs,
                runSpacing: TatuzinSpacing.xs,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
