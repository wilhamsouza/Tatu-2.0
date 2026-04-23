import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';
import 'app_status_badge.dart';

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
    required this.enabled,
  });

  final String title;
  final String description;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tatuzinTokens;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: tokens.sectionPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TatuzinSpacing.sm,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    AppStatusBadge(
                      label: enabled ? 'Disponivel' : 'Sem permissao',
                      tone: enabled ? AppTone.primary : AppTone.info,
                    ),
                  ],
                ),
                Text(description),
                Row(
                  children: <Widget>[
                    Icon(
                      enabled
                          ? Icons.arrow_outward_rounded
                          : Icons.lock_outline_rounded,
                    ),
                    const SizedBox(width: TatuzinSpacing.xs),
                    Expanded(
                      child: Text(
                        enabled
                            ? 'Pronto para abrir neste dispositivo.'
                            : 'Este perfil nao possui acesso a este modulo.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
