import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../../../core/connectivity/application/providers/connectivity_providers.dart';
import '../../../../core/connectivity/domain/entities/connectivity_status.dart';
import '../../../../core/permissions/application/permission_service.dart';
import '../../../../core/ui/theme/app_theme_tokens.dart';
import '../../../../core/ui/widgets/app_metric_tile.dart';
import '../../../../core/ui/widgets/app_section_card.dart';
import '../../../../core/ui/widgets/module_card.dart';
import '../../../pdv/sync_status/presentation/providers/sync_status_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionNotifierProvider).asData?.value;
    final connectivityStatus = ref.watch(currentConnectivityStatusProvider);
    final syncSnapshot = ref.watch(syncNotifierProvider).asData?.value;
    final permissionService = const PermissionService();

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final roles = session.user.roles;
    final pendingOperations =
        syncSnapshot?.pendingOperations ?? session.syncStatus.pendingOperations;
    final failedOperations =
        syncSnapshot?.failedOperations ?? session.syncStatus.failedOperations;
    final lastSuccessfulSyncAt =
        syncSnapshot?.lastSuccessfulSyncAt ??
        session.syncStatus.lastSuccessfulSyncAt;
    final tokens = context.tatuzinTokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel inicial'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await ref.read(sessionNotifierProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Sair'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: tokens.pagePadding,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[tokens.heroStart, tokens.heroEnd],
                ),
                borderRadius: BorderRadius.circular(tokens.heroRadius),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: tokens.shadowColor,
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(TatuzinSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: TatuzinSpacing.sm,
                  children: <Widget>[
                    Text(
                      'Tatuzin 2.0',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: tokens.heroForeground),
                    ),
                    Text(
                      'Painel unificado do PDV offline-first, ERP server-first e CRM server-first.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.heroForeground.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: TatuzinSpacing.sm),
                    Wrap(
                      spacing: TatuzinSpacing.sm,
                      runSpacing: TatuzinSpacing.sm,
                      children: <Widget>[
                        AppMetricTile(
                          label: 'Usuario',
                          value: session.user.name,
                          tone: AppTone.primary,
                        ),
                        AppMetricTile(
                          label: 'Empresa',
                          value: session.companyContext.companyName,
                          tone: AppTone.info,
                        ),
                        AppMetricTile(
                          label: 'Conectividade',
                          value: _connectivityLabel(connectivityStatus),
                          tone: connectivityStatus == ConnectivityStatus.offline
                              ? AppTone.warning
                              : AppTone.success,
                        ),
                        AppMetricTile(
                          label: 'Pendentes',
                          value: '$pendingOperations',
                          tone: AppTone.sync,
                        ),
                        AppMetricTile(
                          label: 'Falhas',
                          value: '$failedOperations',
                          tone: failedOperations > 0
                              ? AppTone.danger
                              : AppTone.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: TatuzinSpacing.sm),
                    Text(
                      'Papeis: ${session.user.roles.map((role) => role.label).join(', ')}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.heroForeground.withValues(alpha: 0.88),
                      ),
                    ),
                    Text(
                      'Device ID: ${session.deviceRegistration.deviceId}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.heroForeground.withValues(alpha: 0.88),
                      ),
                    ),
                    if (lastSuccessfulSyncAt != null)
                      Text(
                        'Ultimo sync bem-sucedido: ${lastSuccessfulSyncAt.toLocal()}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.heroForeground.withValues(alpha: 0.88),
                        ),
                      ),
                    const SizedBox(height: TatuzinSpacing.xs),
                    OutlinedButton(
                      onPressed:
                          connectivityStatus == ConnectivityStatus.offline
                          ? null
                          : () async {
                              final summary = await ref
                                  .read(syncNotifierProvider.notifier)
                                  .runNow();
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Sync executado: ${summary.syncedOperations} operacao(oes) sincronizada(s), ${summary.appliedUpdates} update(s) aplicado(s).',
                                  ),
                                ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.heroForeground,
                        side: BorderSide(
                          color: tokens.heroForeground.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Text('Sincronizar agora'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TatuzinSpacing.lg),
            AppSectionCard(
              title: 'Modulos habilitados',
              subtitle:
                  'Cada modulo abaixo respeita o papel do usuario e o contexto da empresa atual.',
              child: Column(
                children: <Widget>[
                  ModuleCard(
                    title: 'PDV Local',
                    description:
                        'Operacao offline-first, catalogo materializado e base do checkout local.',
                    enabled: permissionService.canAccessPdv(roles),
                    onTap: () => context.go('/pdv'),
                  ),
                  ModuleCard(
                    title: 'ERP Cloud',
                    description:
                        'Produtos, variantes, estoque e gestao administrativa server-first.',
                    enabled: permissionService.canAccessErp(roles),
                    onTap: () => context.go('/erp'),
                  ),
                  ModuleCard(
                    title: 'CRM Cloud',
                    description:
                        'Clientes, historico de compras e resumo operacional por relacionamento.',
                    enabled: permissionService.canAccessCrm(roles),
                    onTap: () => context.go('/crm'),
                  ),
                  ModuleCard(
                    title: 'Configuracoes',
                    description:
                        'Sessao, device identity, sync e parametros centrais da plataforma.',
                    enabled: permissionService.canAccessSettings(roles),
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _connectivityLabel(ConnectivityStatus? status) {
    switch (status) {
      case ConnectivityStatus.online:
        return 'online';
      case ConnectivityStatus.offline:
        return 'offline';
      case ConnectivityStatus.limited:
        return 'limitada';
      case null:
        return 'verificando';
    }
  }
}
