import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../../../core/connectivity/application/providers/connectivity_providers.dart';
import '../../../../core/connectivity/domain/entities/connectivity_status.dart';
import '../../../../core/permissions/domain/entities/app_role.dart';
import '../../../../core/sync/domain/entities/sync_conflict.dart';
import '../../../../core/ui/theme/app_theme_mode.dart';
import '../../../../core/ui/theme/app_theme_tokens.dart';
import '../../../../core/ui/theme/theme_mode_controller.dart';
import '../../../../core/ui/widgets/app_metric_tile.dart';
import '../../../../core/ui/widgets/app_section_card.dart';
import '../../../../core/ui/widgets/app_status_badge.dart';
import '../../../../core/ui/widgets/protected_module_scaffold.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../pdv/sync_status/application/dtos/sync_status_details.dart';
import '../../../pdv/sync_status/domain/entities/sync_log_entry.dart';
import '../../../pdv/sync_status/domain/entities/sync_queue_operation.dart';
import '../../../pdv/sync_status/presentation/providers/sync_status_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _apiBaseUrlController;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionNotifierProvider).asData?.value;
    final connectivityStatus = ref.watch(currentConnectivityStatusProvider);
    final detailsState = ref.watch(syncStatusDetailsNotifierProvider);
    final details = detailsState.asData?.value;
    final themePreference = ref.watch(appThemeModePreferenceProvider);
    final tokens = context.tatuzinTokens;

    if (details != null &&
        _apiBaseUrlController.text != (details.customApiBaseUrl ?? '')) {
      _apiBaseUrlController.text = details.customApiBaseUrl ?? '';
    }

    return ProtectedModuleScaffold(
      title: 'Configuracoes',
      description: 'Parametros globais, identidade visual e operacao central.',
      allowedRoles: const <AppRole>{AppRole.admin},
      child: ListView(
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
                  const AppStatusBadge(
                    label: 'Core Platform',
                    tone: AppTone.primary,
                  ),
                  Text(
                    'Base visual e operacional do Tatuzin',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: tokens.heroForeground,
                    ),
                  ),
                  Text(
                    'Aqui vivem o modo de tema, o endpoint efetivo do backend e a observabilidade do Sync Bridge por dispositivo.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: tokens.heroForeground.withValues(alpha: 0.92),
                    ),
                  ),
                  Wrap(
                    spacing: TatuzinSpacing.sm,
                    runSpacing: TatuzinSpacing.sm,
                    children: <Widget>[
                      AppMetricTile(
                        label: 'Tema atual',
                        value: themePreference.label,
                        tone: AppTone.primary,
                      ),
                      AppMetricTile(
                        label: 'Rede',
                        value: _connectivityLabel(connectivityStatus),
                        tone: connectivityStatus == ConnectivityStatus.offline
                            ? AppTone.warning
                            : AppTone.success,
                      ),
                      if (session != null)
                        AppMetricTile(
                          label: 'Empresa',
                          value: session.companyContext.companyName,
                          tone: AppTone.info,
                        ),
                      if (session != null)
                        AppMetricTile(
                          label: 'Device',
                          value: session.deviceRegistration.platform,
                          tone: AppTone.sync,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TatuzinSpacing.lg),
          AppSectionCard(
            title: 'Contexto global',
            subtitle:
                'Sessao, tenancy e informacoes essenciais do dispositivo atual.',
            action: AppStatusBadge(
              label: session == null ? 'Sem sessao' : 'Sessao ativa',
              tone: session == null ? AppTone.warning : AppTone.success,
            ),
            child: session == null
                ? const Text(
                    'Faca login com um perfil administrador para editar parametros globais.',
                  )
                : Wrap(
                    spacing: TatuzinSpacing.sm,
                    runSpacing: TatuzinSpacing.sm,
                    children: <Widget>[
                      AppMetricTile(
                        label: 'Company ID',
                        value: session.companyContext.companyId,
                      ),
                      AppMetricTile(
                        label: 'Usuario',
                        value: session.user.name,
                      ),
                      AppMetricTile(
                        label: 'Papeis',
                        value: session.user.roles
                            .map((role) => role.label)
                            .join(', '),
                      ),
                      AppMetricTile(
                        label: 'Token expira em',
                        value: CurrencyUtils.formatDateTime(
                          session.tokens.expiresAt,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: TatuzinSpacing.lg),
          AppSectionCard(
            title: 'Aparencia',
            subtitle:
                'O design system usa a direcao Boutique Quente com suporte a tema do sistema e override manual por usuario/dispositivo.',
            tone: AppTone.primary,
            action: AppStatusBadge(
              label: themePreference.label,
              tone: AppTone.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<AppThemeModePreference>(
                    segments: AppThemeModePreference.values
                        .map(
                          (mode) => ButtonSegment<AppThemeModePreference>(
                            value: mode,
                            icon: Icon(mode.icon),
                            label: Text(mode.label),
                          ),
                        )
                        .toList(),
                    selected: <AppThemeModePreference>{themePreference},
                    onSelectionChanged: (selection) {
                      _updateThemeMode(selection.first);
                    },
                  ),
                ),
                const SizedBox(height: TatuzinSpacing.sm),
                Text(themePreference.description),
                const SizedBox(height: TatuzinSpacing.md),
                Wrap(
                  spacing: TatuzinSpacing.sm,
                  runSpacing: TatuzinSpacing.sm,
                  children: <Widget>[
                    AppMetricTile(
                      label: 'Modo preferido',
                      value: themePreference.label,
                      tone: AppTone.primary,
                    ),
                    const AppMetricTile(
                      label: 'Fonte base',
                      value: 'Noto Sans',
                      tone: AppTone.info,
                    ),
                    AppMetricTile(
                      label: 'Aplicacao',
                      value: themePreference == AppThemeModePreference.system
                          ? 'Sistema + manual'
                          : 'Manual',
                      tone: AppTone.sync,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TatuzinSpacing.lg),
          AppSectionCard(
            title: 'Endpoint do backend',
            subtitle:
                'Controle local do destino do backend para PDV, ERP, CRM e Sync Bridge neste dispositivo.',
            tone: AppTone.info,
            action: AppStatusBadge(
              label: details?.customApiBaseUrl == null
                  ? 'Padrao da plataforma'
                  : 'Override local',
              tone: details?.customApiBaseUrl == null
                  ? AppTone.info
                  : AppTone.warning,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _apiBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'API Base URL',
                    hintText: 'http://127.0.0.1:3333',
                  ),
                ),
                const SizedBox(height: TatuzinSpacing.sm),
                if (details != null) ...<Widget>[
                  Text('Endpoint efetivo: ${details.effectiveApiBaseUrl}'),
                  Text(
                    details.customApiBaseUrl == null
                        ? 'Nenhum override salvo: usando o valor padrao por plataforma.'
                        : 'Override salvo localmente neste dispositivo.',
                  ),
                ] else if (detailsState.isLoading)
                  const Text('Carregando configuracao de sync...')
                else if (detailsState.hasError)
                  Text('Falha ao carregar endpoint: ${detailsState.error}'),
                const SizedBox(height: TatuzinSpacing.md),
                Wrap(
                  spacing: TatuzinSpacing.sm,
                  runSpacing: TatuzinSpacing.sm,
                  children: <Widget>[
                    FilledButton(
                      onPressed: detailsState.isLoading ? null : _saveApiBaseUrl,
                      child: Text(
                        detailsState.isLoading
                            ? 'Salvando...'
                            : 'Salvar endpoint',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: detailsState.isLoading
                          ? null
                          : _resetApiBaseUrl,
                      child: const Text('Restaurar padrao'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TatuzinSpacing.lg),
          _buildSyncBridgeCard(context, detailsState, details),
        ],
      ),
    );
  }

  Widget _buildSyncBridgeCard(
    BuildContext context,
    AsyncValue<SyncStatusDetails> detailsState,
    SyncStatusDetails? details,
  ) {
    final snapshot = details?.snapshot;
    final connectivityStatus = ref.watch(currentConnectivityStatusProvider);
    final isOffline = connectivityStatus == ConnectivityStatus.offline;

    return AppSectionCard(
      title: 'Sync Bridge',
      subtitle:
          'Outbox, inbox, retries, conflitos e observabilidade do dispositivo.',
      tone: AppTone.sync,
      action: AppStatusBadge(
        label: isOffline ? 'Offline' : 'Pronto',
        tone: isOffline ? AppTone.warning : AppTone.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (detailsState.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: TatuzinSpacing.sm),
              child: Text(
                'Falha ao carregar painel de sync: ${detailsState.error}',
              ),
            ),
          if (snapshot != null) ...<Widget>[
            Wrap(
              spacing: TatuzinSpacing.sm,
              runSpacing: TatuzinSpacing.sm,
              children: <Widget>[
                AppMetricTile(
                  label: 'Pendentes',
                  value: '${snapshot.pendingOperations}',
                  tone: AppTone.sync,
                ),
                AppMetricTile(
                  label: 'Falhas',
                  value: '${snapshot.failedOperations}',
                  tone: snapshot.failedOperations > 0
                      ? AppTone.danger
                      : AppTone.success,
                ),
                AppMetricTile(
                  label: 'Cursor',
                  value: details?.cursor ?? 'sem cursor',
                  tone: AppTone.info,
                ),
                AppMetricTile(
                  label: 'Rede',
                  value: _connectivityLabel(connectivityStatus),
                  tone: isOffline ? AppTone.warning : AppTone.success,
                ),
              ],
            ),
            const SizedBox(height: TatuzinSpacing.sm),
            Text(
              snapshot.lastSuccessfulSyncAt == null
                  ? 'Ultimo sync bem-sucedido: ainda nao ocorreu.'
                  : 'Ultimo sync bem-sucedido: ${CurrencyUtils.formatDateTime(snapshot.lastSuccessfulSyncAt!)}',
            ),
            const SizedBox(height: TatuzinSpacing.md),
          ],
          Wrap(
            spacing: TatuzinSpacing.sm,
            runSpacing: TatuzinSpacing.sm,
            children: <Widget>[
              FilledButton(
                onPressed: detailsState.isLoading || isOffline
                    ? null
                    : _runSyncNow,
                child: const Text('Sincronizar agora'),
              ),
              OutlinedButton(
                onPressed: detailsState.isLoading ? null : _refreshDetails,
                child: const Text('Atualizar painel'),
              ),
              OutlinedButton(
                onPressed: detailsState.isLoading
                    ? null
                    : _retryIssueOperations,
                child: const Text('Reprocessar falhas/conflitos'),
              ),
            ],
          ),
          const Divider(),
          Text(
            'Fila recente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: TatuzinSpacing.sm),
          if (details == null || details.recentOperations.isEmpty)
            const Text('Nenhuma operacao registrada no outbox ainda.')
          else
            ...details.recentOperations.map(_buildQueueTile),
          const Divider(),
          Text(
            'Conflitos recentes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: TatuzinSpacing.sm),
          if (details == null || details.recentConflicts.isEmpty)
            const Text('Nenhum conflito registrado no dispositivo.')
          else
            ...details.recentConflicts.map(_buildConflictTile),
          const Divider(),
          Text(
            'Logs recentes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: TatuzinSpacing.sm),
          if (details == null || details.recentLogs.isEmpty)
            const Text('Nenhum log de sync disponivel ainda.')
          else
            ...details.recentLogs.map(_buildLogTile),
        ],
      ),
    );
  }

  Widget _buildLogTile(SyncLogEntry log) {
    return _SignalTile(
      icon: _iconForLevel(log.level),
      tone: _toneForLogLevel(log.level),
      title: log.message,
      subtitle:
          '${CurrencyUtils.formatDateTime(log.createdAt)}${_formatContext(log)}',
    );
  }

  Widget _buildQueueTile(SyncQueueOperation operation) {
    return _SignalTile(
      icon: _iconForStatus(operation.status.wireValue),
      tone: _toneForOperationStatus(operation.status.wireValue),
      title: '${operation.type.wireValue} - ${operation.entityLocalId}',
      subtitle: [
        'status: ${operation.status.wireValue}',
        'tentativas: ${operation.retries}',
        'atualizado: ${CurrencyUtils.formatDateTime(operation.updatedAt)}',
        if (operation.lastError != null && operation.lastError!.isNotEmpty)
          'erro: ${operation.lastError}',
      ].join('\n'),
      trailing: operation.canRetry
          ? IconButton(
              onPressed: () => _retryOperation(operation.operationId),
              icon: const Icon(Icons.refresh),
              tooltip: 'Reprocessar operacao',
            )
          : null,
    );
  }

  Widget _buildConflictTile(SyncConflict conflict) {
    final presentation = _describeConflict(conflict);
    final backendMessage = conflict.details['message'] as String?;

    return _SignalTile(
      icon: Icons.warning_amber_rounded,
      tone: AppTone.warning,
      title: presentation.title,
      subtitle: [
        presentation.description,
        if (presentation.nextStep != null)
          'Acao sugerida: ${presentation.nextStep}',
        if (backendMessage != null && backendMessage.isNotEmpty)
          'Backend: $backendMessage',
        CurrencyUtils.formatDateTime(conflict.createdAt),
      ].join('\n'),
    );
  }

  IconData _iconForStatus(String status) {
    switch (status) {
      case 'synced':
        return Icons.check_circle_outline;
      case 'failed':
      case 'conflict':
        return Icons.sync_problem_outlined;
      case 'sending':
        return Icons.cloud_upload_outlined;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  IconData _iconForLevel(String level) {
    switch (level) {
      case 'warning':
        return Icons.error_outline;
      case 'error':
        return Icons.cancel_outlined;
      case 'info':
      default:
        return Icons.sync;
    }
  }

  AppTone _toneForOperationStatus(String status) {
    switch (status) {
      case 'synced':
        return AppTone.success;
      case 'failed':
      case 'conflict':
        return AppTone.danger;
      case 'sending':
        return AppTone.sync;
      case 'pending':
      default:
        return AppTone.info;
    }
  }

  AppTone _toneForLogLevel(String level) {
    switch (level) {
      case 'warning':
        return AppTone.warning;
      case 'error':
        return AppTone.danger;
      case 'info':
      default:
        return AppTone.sync;
    }
  }

  String _formatContext(SyncLogEntry log) {
    if (log.context == null || log.context!.isEmpty) {
      return '';
    }
    final items = log.context!.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');
    return '\n$items';
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

  _ConflictPresentation _describeConflict(SyncConflict conflict) {
    switch (conflict.conflictType) {
      case 'quick_customer_missing':
        return const _ConflictPresentation(
          title: 'Cliente rapido ainda nao sincronizado',
          description:
              'A operacao depende de um cliente criado localmente que ainda nao foi confirmado no backend.',
          nextStep:
              'Reprocesse primeiro o quick_customer e depois a venda ou a nota.',
        );
      case 'sale_missing':
        return const _ConflictPresentation(
          title: 'Venda remota ainda nao confirmada',
          description:
              'A nota a receber depende da sincronizacao da venda principal antes de ser aceita pelo backend.',
          nextStep:
              'Sincronize a sale correspondente e depois reenvie a receivable_note.',
        );
      case 'cash_movement_invalid':
        return const _ConflictPresentation(
          title: 'Movimento de caixa recusado',
          description:
              'O backend recusou o movimento de caixa por inconsistencia de payload ou regra operacional.',
          nextStep:
              'Revise a sessao de caixa e reprocesse a operacao somente apos corrigir a causa.',
        );
      default:
        return _ConflictPresentation(
          title: conflict.conflictType,
          description:
              'O backend registrou um conflito de sincronizacao que exige analise antes do reenvio.',
        );
    }
  }

  Future<void> _updateThemeMode(AppThemeModePreference preference) async {
    try {
      await ref
          .read(appThemeModePreferenceProvider.notifier)
          .setPreference(preference);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tema atualizado para ${preference.label.toLowerCase()}.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao atualizar tema: $error')),
      );
    }
  }

  Future<void> _saveApiBaseUrl() async {
    await ref
        .read(syncStatusDetailsNotifierProvider.notifier)
        .saveApiBaseUrl(_apiBaseUrlController.text);
    if (!mounted) {
      return;
    }
    final nextState = ref.read(syncStatusDetailsNotifierProvider);
    if (nextState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao salvar endpoint: ${nextState.error}')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Endpoint do backend atualizado.')),
    );
  }

  Future<void> _resetApiBaseUrl() async {
    await ref.read(syncStatusDetailsNotifierProvider.notifier).resetApiBaseUrl();
    if (!mounted) {
      return;
    }
    final nextState = ref.read(syncStatusDetailsNotifierProvider);
    if (nextState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao restaurar endpoint: ${nextState.error}'),
        ),
      );
      return;
    }
    _apiBaseUrlController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Endpoint restaurado para o padrao.')),
    );
  }

  Future<void> _refreshDetails() async {
    await ref.read(syncStatusDetailsNotifierProvider.notifier).refresh();
  }

  Future<void> _runSyncNow() async {
    final summary = await ref.read(syncNotifierProvider.notifier).runNow();
    await ref.read(syncStatusDetailsNotifierProvider.notifier).refresh();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sync executado: ${summary.syncedOperations} sincronizada(s), ${summary.conflictOperations} conflito(s), ${summary.appliedUpdates} update(s).',
        ),
      ),
    );
  }

  Future<void> _retryIssueOperations() async {
    await ref
        .read(syncStatusDetailsNotifierProvider.notifier)
        .retryIssueOperations();
    if (!mounted) {
      return;
    }

    final nextState = ref.read(syncStatusDetailsNotifierProvider);
    if (nextState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha ao reprocessar operacoes com problema: ${nextState.error}',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Operacoes com falha/conflito voltaram para a fila.'),
      ),
    );
  }

  Future<void> _retryOperation(String operationId) async {
    await ref
        .read(syncStatusDetailsNotifierProvider.notifier)
        .retryOperation(operationId);
    if (!mounted) {
      return;
    }

    final nextState = ref.read(syncStatusDetailsNotifierProvider);
    if (nextState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha ao reprocessar operacao $operationId: ${nextState.error}',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Operacao $operationId voltou para pending.')),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final AppTone tone;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tatuzinTokens;
    final colors = tokens.tone(tone);

    return Padding(
      padding: const EdgeInsets.only(bottom: TatuzinSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(tokens.panelRadius),
          border: Border.all(color: colors.border),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: TatuzinSpacing.md,
            vertical: TatuzinSpacing.xs,
          ),
          leading: Icon(icon, color: colors.foreground),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foreground.withValues(alpha: 0.9),
            ),
          ),
          trailing: trailing,
        ),
      ),
    );
  }
}

class _ConflictPresentation {
  const _ConflictPresentation({
    required this.title,
    required this.description,
    this.nextStep,
  });

  final String title;
  final String description;
  final String? nextStep;
}
