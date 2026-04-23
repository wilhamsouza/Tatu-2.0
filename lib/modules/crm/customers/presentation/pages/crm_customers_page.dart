import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/permissions/domain/entities/app_role.dart';
import '../../../../../core/ui/theme/app_theme_tokens.dart';
import '../../../../../core/ui/widgets/app_metric_tile.dart';
import '../../../../../core/ui/widgets/app_record_card.dart';
import '../../../../../core/ui/widgets/app_section_card.dart';
import '../../../../../core/ui/widgets/app_status_badge.dart';
import '../../../../../core/ui/widgets/protected_module_scaffold.dart';
import '../../../../../core/utils/currency_utils.dart';
import '../../application/notifiers/crm_customers_notifier.dart';
import '../../domain/entities/crm_entities.dart';

class CrmCustomersPage extends StatelessWidget {
  const CrmCustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProtectedModuleScaffold(
      title: 'CRM Cloud',
      description: 'Relacionamento, historico e visao consolidada do cliente.',
      allowedRoles: <AppRole>{AppRole.admin, AppRole.manager, AppRole.crmUser},
      child: _CrmBody(),
    );
  }
}

class _CrmBody extends ConsumerStatefulWidget {
  const _CrmBody();

  @override
  ConsumerState<_CrmBody> createState() => _CrmBodyState();
}

class _CrmBodyState extends ConsumerState<_CrmBody> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crmCustomersNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeader(context, state),
        const SizedBox(height: 16),
        Expanded(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                _ErrorState(error: error, onRetry: _refresh),
            data: (directory) => LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;
                final listPane = _buildDirectoryPane(context, directory);
                final detailPane = _buildDetailPane(
                  context,
                  directory,
                  scrollable: isWide,
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 2, child: listPane),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: detailPane),
                    ],
                  );
                }

                return ListView(
                  children: <Widget>[
                    SizedBox(height: 520, child: listPane),
                    const SizedBox(height: 16),
                    detailPane,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<CrmDirectoryState> directoryState,
  ) {
    final directory = directoryState.asData?.value;
    final customers = directory?.customers ?? const <CrmCustomer>[];
    final selectedSummary = directory?.selectedSummary;

    return AppSectionCard(
      title: 'CRM server-first',
      subtitle:
          'Clientes, historico e resumo financeiro vivem no backend. O app consulta a base consolidada e tambem enxerga o cliente rapido sincronizado a partir do PDV.',
      tone: AppTone.primary,
      action: Wrap(
        spacing: TatuzinSpacing.xs,
        runSpacing: TatuzinSpacing.xs,
        children: <Widget>[
          FilledButton.tonalIcon(
            onPressed: directoryState.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Atualizar'),
          ),
          FilledButton.tonalIcon(
            onPressed: directoryState.isLoading ? null : _exportSegmentCsv,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Exportar CSV'),
          ),
        ],
      ),
      child: Wrap(
        spacing: TatuzinSpacing.sm,
        runSpacing: TatuzinSpacing.sm,
        children: <Widget>[
          _MetricChip(label: 'Clientes', value: '${customers.length}'),
          _MetricChip(
            label: 'Selecionado',
            value: selectedSummary?.customer.name ?? 'Nenhum',
          ),
          _MetricChip(
            label: 'Em aberto',
            value: selectedSummary == null
                ? 'R\$ 0,00'
                : CurrencyUtils.formatMoney(
                    selectedSummary.totalOutstandingInCents,
                  ),
          ),
          _MetricChip(
            label: 'Compras',
            value: '${selectedSummary?.totalPurchases ?? 0}',
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryPane(
    BuildContext context,
    CrmDirectoryState directory,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionCard(
          title: 'Diretorio de clientes',
          action: FilledButton.icon(
            onPressed: _openCreateCustomerDialog,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Novo cliente'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome ou telefone',
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: () => _search(_searchController.text),
                    child: const Text('Buscar'),
                  ),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                    child: const Text('Limpar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _SectionCard(
            title: 'Clientes encontrados',
            child: directory.customers.isEmpty
                ? const Text(
                    'Nenhum cliente encontrado. Voce pode criar um cadastro completo ou aguardar a ingestao dos clientes rapidos vindos do PDV.',
                  )
                : ListView.builder(
                    itemCount: directory.customers.length,
                    itemBuilder: (context, index) {
                      final customer = directory.customers[index];
                      final isSelected =
                          directory.selectedCustomerId == customer.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _selectCustomer(customer.id),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          customer.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      _SourceChip(source: customer.source),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Telefone: ${customer.phone}'),
                                  if ((customer.email ?? '').isNotEmpty)
                                    Text('Email: ${customer.email}'),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Compras: ${customer.totalPurchases} | Total gasto: ${CurrencyUtils.formatMoney(customer.totalSpentInCents)}',
                                  ),
                                  Text(
                                    'Em aberto: ${CurrencyUtils.formatMoney(customer.totalOutstandingInCents)}',
                                  ),
                                  Text(
                                    'Notas abertas/vencidas: ${customer.openReceivablesCount}/${customer.overdueReceivablesCount}',
                                  ),
                                  if (customer.lastPurchaseAt != null)
                                    Text(
                                      'Ultima compra: ${CurrencyUtils.formatDateTime(customer.lastPurchaseAt!)}',
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailPane(
    BuildContext context,
    CrmDirectoryState directory, {
    required bool scrollable,
  }) {
    final summary = directory.selectedSummary;
    final history = directory.selectedHistory;
    final selectedCustomer = directory.selectedCustomer;

    if (summary == null || history == null || selectedCustomer == null) {
      return _SectionCard(
        title: 'Detalhes do cliente',
        child: const Text(
          'Selecione um cliente para visualizar resumo consolidado, notas a receber e historico de compras.',
        ),
      );
    }

    final sections = <Widget>[
      _SectionCard(
        title: 'Resumo do cliente',
        action: FilledButton.tonalIcon(
          onPressed: () => _openEditCustomerDialog(selectedCustomer),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar cadastro'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              summary.customer.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text('Telefone: ${summary.customer.phone}'),
            Text('Email: ${summary.customer.email ?? '-'}'),
            Text('Endereco: ${summary.customer.address ?? '-'}'),
            Text('Observacoes: ${summary.customer.notes ?? '-'}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _MetricChip(
                  label: 'Total gasto',
                  value: CurrencyUtils.formatMoney(summary.totalSpentInCents),
                ),
                _MetricChip(
                  label: 'Ticket medio',
                  value: CurrencyUtils.formatMoney(
                    summary.averageTicketInCents,
                  ),
                ),
                _MetricChip(
                  label: 'Compras',
                  value: '${summary.totalPurchases}',
                ),
                _MetricChip(
                  label: 'Em aberto',
                  value: CurrencyUtils.formatMoney(
                    summary.totalOutstandingInCents,
                  ),
                ),
                _MetricChip(
                  label: 'Notas abertas',
                  value: '${summary.openReceivablesCount}',
                ),
                _MetricChip(
                  label: 'Notas vencidas',
                  value: '${summary.overdueReceivablesCount}',
                ),
              ],
            ),
            if (summary.lastPurchaseAt != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Ultima compra em ${CurrencyUtils.formatDateTime(summary.lastPurchaseAt!)}',
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Pendencias financeiras',
        child: summary.receivables.isEmpty
            ? const Text('Nenhuma nota em aberto para este cliente.')
            : Column(
                children: summary.receivables.map((receivable) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecordCard(
                      title: 'Nota ${receivable.noteId.substring(0, 8)}',
                      badge: _ReceivableStatusChip(status: receivable.status),
                      lines: <String>[
                        'Venda: ${receivable.saleId.substring(0, 8)}',
                        'Valor original: ${CurrencyUtils.formatMoney(receivable.originalAmountInCents)}',
                        'Pago: ${CurrencyUtils.formatMoney(receivable.paidAmountInCents)}',
                        'Saldo em aberto: ${CurrencyUtils.formatMoney(receivable.outstandingAmountInCents)}',
                        'Emissao: ${CurrencyUtils.formatDate(receivable.issueDate)}',
                        'Vencimento: ${CurrencyUtils.formatDate(receivable.dueDate)}',
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Historico de compras',
        child: history.purchases.isEmpty
            ? const Text('Nenhuma compra sincronizada para este cliente.')
            : Column(
                children: history.purchases.map((purchase) {
                  final paymentLabels = purchase.paymentMethods
                      .map(_paymentMethodLabel)
                      .join(', ');
                  final itemLabels = purchase.items
                      .map(
                        (item) =>
                            '${item.quantity}x ${item.displayName} (${CurrencyUtils.formatMoney(item.totalPriceInCents)})',
                      )
                      .toList();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecordCard(
                      title: 'Compra ${purchase.saleId.substring(0, 8)}',
                      badge: purchase.receivableStatus == null
                          ? null
                          : _ReceivableStatusChip(
                              status: purchase.receivableStatus!,
                            ),
                      lines: <String>[
                        'Data: ${CurrencyUtils.formatDateTime(purchase.createdAt)}',
                        'Itens: ${purchase.itemCount}',
                        'Subtotal: ${CurrencyUtils.formatMoney(purchase.subtotalInCents)}',
                        'Desconto: ${CurrencyUtils.formatMoney(purchase.discountInCents)}',
                        'Total: ${CurrencyUtils.formatMoney(purchase.totalInCents)}',
                        'Pagamento: $paymentLabels',
                        if (purchase.outstandingAmountInCents > 0)
                          'Saldo em aberto: ${CurrencyUtils.formatMoney(purchase.outstandingAmountInCents)}',
                        if (purchase.receivableDueDate != null)
                          'Vencimento da nota: ${CurrencyUtils.formatDate(purchase.receivableDueDate!)}',
                        ...itemLabels,
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    ];

    if (scrollable) {
      return ListView(children: sections);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Future<void> _refresh() async {
    try {
      await ref.read(crmCustomersNotifierProvider.notifier).refresh();
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _search(String query) async {
    try {
      await ref.read(crmCustomersNotifierProvider.notifier).search(query);
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _selectCustomer(String customerId) async {
    try {
      await ref
          .read(crmCustomersNotifierProvider.notifier)
          .selectCustomer(customerId);
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openCreateCustomerDialog() async {
    final result = await showDialog<_CustomerDialogResult>(
      context: context,
      builder: (dialogContext) => const _CustomerDialog(),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(crmCustomersNotifierProvider.notifier)
          .createCustomer(
            name: result.name,
            phone: result.phone,
            email: result.email,
            address: result.address,
            notes: result.notes,
          );
      _showMessage('Cliente criado com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openEditCustomerDialog(CrmCustomer customer) async {
    final result = await showDialog<_CustomerDialogResult>(
      context: context,
      builder: (dialogContext) => _CustomerDialog(customer: customer),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(crmCustomersNotifierProvider.notifier)
          .updateCustomer(
            customerId: customer.id,
            name: result.name,
            phone: result.phone,
            email: result.email,
            address: result.address,
            notes: result.notes,
          );
      _showMessage('Cliente atualizado com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _exportSegmentCsv() async {
    try {
      final csv = await ref
          .read(crmCustomersNotifierProvider.notifier)
          .exportCurrentSegmentCsv();
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}tatuzin-crm-segment.csv',
      );
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'Exportacao CSV do segmento CRM Tatuzin 2.0',
        ),
      );
      _showMessage('CSV do CRM pronto para compartilhar.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError
            ? Theme.of(context).colorScheme.errorContainer
            : null,
        content: Text(message),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: _SectionCard(
          title: 'Falha ao carregar o CRM',
          action: FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Tentar novamente'),
          ),
          child: Text(error.toString()),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      action: action,
      child: child,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppMetricTile(label: label, value: value, tone: AppTone.primary);
  }
}

AppTone _crmToneForSource(String source) {
  switch (source) {
    case 'quick_customer':
      return AppTone.sync;
    default:
      return AppTone.info;
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.title, required this.lines, this.badge});

  final String title;
  final List<String> lines;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return AppRecordCard(
      title: title,
      lines: lines,
      badge: badge,
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final label = source == 'quick_customer' ? 'Quick sync' : 'Manual';
    return AppStatusBadge(
      label: label,
      tone: _crmToneForSource(source),
    );
  }
}

class _ReceivableStatusChip extends StatelessWidget {
  const _ReceivableStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'pending' => 'Pendente',
      'partially_paid' => 'Parcial',
      'paid' => 'Pago',
      'overdue' => 'Vencido',
      'canceled' => 'Cancelado',
      _ => status,
    };
    final tone = switch (status) {
      'pending' => AppTone.note,
      'partially_paid' => AppTone.warning,
      'paid' => AppTone.success,
      'overdue' => AppTone.danger,
      'canceled' => AppTone.info,
      _ => AppTone.info,
    };

    return AppStatusBadge(label: label, tone: tone);
  }
}

class _CustomerDialogResult {
  const _CustomerDialogResult({
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? notes;
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog({this.customer});

  final CrmCustomer? customer;

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.customer?.phone ?? '',
    );
    _emailController = TextEditingController(
      text: widget.customer?.email ?? '',
    );
    _addressController = TextEditingController(
      text: widget.customer?.address ?? '',
    );
    _notesController = TextEditingController(
      text: widget.customer?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar cliente' : 'Novo cliente'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Endereco'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Observacoes'),
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Atualizar' : 'Salvar'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      setState(() {
        _errorMessage = 'Nome e telefone sao obrigatorios.';
      });
      return;
    }

    Navigator.of(context).pop(
      _CustomerDialogResult(
        name: name,
        phone: phone,
        email: _normalizeOptional(_emailController.text),
        address: _normalizeOptional(_addressController.text),
        notes: _normalizeOptional(_notesController.text),
      ),
    );
  }
}

String? _normalizeOptional(String rawValue) {
  final trimmed = rawValue.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _paymentMethodLabel(String paymentMethod) {
  return switch (paymentMethod) {
    'cash' => 'Dinheiro',
    'pix' => 'Pix',
    'note' => 'Nota',
    _ => paymentMethod,
  };
}
