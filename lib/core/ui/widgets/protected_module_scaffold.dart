import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/notifiers/session_notifier.dart';
import '../../permissions/application/permission_service.dart';
import '../../permissions/domain/entities/app_role.dart';
import '../theme/app_theme_tokens.dart';
import 'app_section_card.dart';

class ProtectedModuleScaffold extends ConsumerWidget {
  const ProtectedModuleScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.allowedRoles,
    required this.child,
  });

  final String title;
  final String description;
  final Set<AppRole> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final permissionService = const PermissionService();
    final session = sessionState.asData?.value;
    final tokens = context.tatuzinTokens;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[tokens.canvasMuted, tokens.canvas],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: tokens.pagePadding,
            child: session == null
                ? _MessageCard(
                    title: 'Sessao necessaria',
                    description: 'Faca login para acessar este modulo.',
                    actionLabel: 'Ir para login',
                    onAction: () => context.go('/login'),
                  )
                : !permissionService.hasAnyRole(session.user.roles, allowedRoles)
                ? _MessageCard(
                    title: 'Acesso restrito',
                    description:
                        'O papel atual nao possui permissao para acessar este modulo.',
                    actionLabel: 'Voltar ao dashboard',
                    onAction: () => context.go('/dashboard'),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AppSectionCard(
          title: title,
          subtitle: description,
          tone: AppTone.info,
          child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ),
      ),
    );
  }
}
