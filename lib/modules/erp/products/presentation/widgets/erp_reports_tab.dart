import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/currency_utils.dart';
import '../../application/notifiers/erp_reports_notifier.dart';
import '../../domain/entities/erp_entities.dart';

class ErpReportsTab extends ConsumerStatefulWidget {
  const ErpReportsTab({super.key});

  @override
  ConsumerState<ErpReportsTab> createState() => _ErpReportsTabState();
}

class _ErpReportsTabState extends ConsumerState<ErpReportsTab> {
  ErpReportPeriod _selectedPeriod = ErpReportPeriod.daily;

  @override
  Widget build(BuildContext context) {
    final reportsState = ref.watch(erpReportsNotifierProvider);

    return reportsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Falha ao carregar relatorios',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(error.toString()),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (dashboard) {
        final report = dashboard.reportFor(_selectedPeriod);

        return ListView(
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                                'Relatorios e hardening',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Painel administrativo da Fase 6 com leitura diaria, semanal e mensal, incluindo ranking operacional e snapshot financeiro das notas.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_outlined),
                          label: const Text('Atualizar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: ErpReportPeriod.values.map((period) {
                        return ChoiceChip(
                          label: Text(period.label),
                          selected: period == _selectedPeriod,
                          onSelected: (_) {
                            setState(() {
                              _selectedPeriod = period;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Janela: ${CurrencyUtils.formatDate(report.startsAt)} ate ${CurrencyUtils.formatDate(report.endsAt.subtract(const Duration(days: 1)))}',
                    ),
                    Text(
                      'Referencia do painel: ${CurrencyUtils.formatDateTime(dashboard.referenceDate)}',
                    ),
                    Text(
                      'Gerado em: ${CurrencyUtils.formatDateTime(dashboard.generatedAt)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _MetricCard(
                  label: 'Vendas',
                  value: '${report.salesCount}',
                  helper: '${report.itemsSold} item(ns)',
                ),
                _MetricCard(
                  label: 'Receita liquida',
                  value: CurrencyUtils.formatMoney(report.netRevenueInCents),
                  helper:
                      'Ticket medio ${CurrencyUtils.formatMoney(report.averageTicketInCents)}',
                ),
                _MetricCard(
                  label: 'Liquidado',
                  value: CurrencyUtils.formatMoney(
                    report.liquidatedRevenueInCents,
                  ),
                  helper:
                      'Nota ${CurrencyUtils.formatMoney(report.noteRevenueInCents)}',
                ),
                _MetricCard(
                  label: 'Descontos',
                  value: CurrencyUtils.formatMoney(report.discountInCents),
                  helper:
                      'Bruto ${CurrencyUtils.formatMoney(report.grossRevenueInCents)}',
                ),
                _MetricCard(
                  label: 'Em aberto',
                  value: CurrencyUtils.formatMoney(
                    report.openReceivablesInCents,
                  ),
                  helper: '${report.openReceivablesCount} nota(s)',
                ),
                _MetricCard(
                  label: 'Vencido',
                  value: CurrencyUtils.formatMoney(
                    report.overdueReceivablesInCents,
                  ),
                  helper: '${report.overdueReceivablesCount} nota(s)',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Meios de pagamento',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (report.paymentBreakdown.isEmpty)
                      const Text('Nenhum pagamento consolidado nesta janela.')
                    else
                      ...report.paymentBreakdown.map((item) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_paymentLabel(item.method)),
                          subtitle: Text(
                            '${item.transactionCount} transacao(oes)',
                          ),
                          trailing: Text(
                            CurrencyUtils.formatMoney(item.amountInCents),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _RankingSection(title: 'Top produtos', items: report.topProducts),
            const SizedBox(height: 16),
            _RankingSection(title: 'Top variantes', items: report.topVariants),
          ],
        );
      },
    );
  }

  Future<void> _refresh() async {
    await ref.read(erpReportsNotifierProvider.notifier).refresh();
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Dinheiro';
      case 'pix':
        return 'Pix';
      case 'note':
        return 'Nota';
      default:
        return method;
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(helper, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingSection extends StatelessWidget {
  const _RankingSection({required this.title, required this.items});

  final String title;
  final List<ErpReportRankingItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('Nenhuma venda consolidada nesta janela.')
            else
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.unitsSold} unidade(s) em ${item.salesCount} venda(s)',
                  ),
                  trailing: Text(
                    CurrencyUtils.formatMoney(item.revenueInCents),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
