import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/permissions/domain/entities/app_role.dart';
import '../../../../../core/ui/theme/app_theme_tokens.dart';
import '../../../../../core/ui/widgets/app_metric_tile.dart';
import '../../../../../core/ui/widgets/app_record_card.dart';
import '../../../../../core/ui/widgets/app_section_card.dart';
import '../../../../../core/ui/widgets/app_status_badge.dart';
import '../../../../../core/ui/widgets/protected_module_scaffold.dart';
import '../../../../../core/utils/currency_utils.dart';
import '../../application/notifiers/erp_overview_notifier.dart';
import '../../domain/entities/erp_entities.dart';
import '../../domain/repositories/erp_repository.dart';
import '../widgets/erp_reports_tab.dart';

class ErpProductsPage extends StatelessWidget {
  const ErpProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProtectedModuleScaffold(
      title: 'ERP Cloud',
      description:
          'Gestao centralizada do catalogo e da operacao administrativa.',
      allowedRoles: <AppRole>{AppRole.admin, AppRole.manager},
      child: _ErpBody(),
    );
  }
}

class _ErpBody extends ConsumerStatefulWidget {
  const _ErpBody();

  @override
  ConsumerState<_ErpBody> createState() => _ErpBodyState();
}

class _ErpBodyState extends ConsumerState<_ErpBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overviewState = ref.watch(erpOverviewNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildHeaderCard(context, overviewState),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const <Tab>[
            Tab(text: 'Produtos'),
            Tab(text: 'Variantes'),
            Tab(text: 'Estoque'),
            Tab(text: 'Fornecedores'),
            Tab(text: 'Compras'),
            Tab(text: 'Recebiveis'),
            Tab(text: 'Caixa'),
            Tab(text: 'Relatorios'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: overviewState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _buildErrorState(context, error),
            data: (overview) => TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildProductsTab(context, overview),
                _buildVariantsTab(context, overview),
                _buildInventoryTab(context, overview),
                _buildSuppliersTab(context, overview),
                _buildPurchasesTab(context, overview),
                _buildReceivablesTab(context, overview),
                _buildCashTab(context, overview),
                const ErpReportsTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    AsyncValue<ErpOverview> overviewState,
  ) {
    final overview = overviewState.asData?.value;

    return AppSectionCard(
      title: 'ERP server-first',
      subtitle:
          'As camadas online do ERP consolidam catalogo mestre, estoque, compras e relatorios administrativos. O app atua como cliente do backend, mantendo o ERP server-first e isolado do PDV offline-first.',
      tone: AppTone.info,
      action: FilledButton.tonalIcon(
        onPressed: overviewState.isLoading ? null : _refreshOverview,
        icon: const Icon(Icons.refresh_outlined),
        label: const Text('Atualizar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (overviewState.isLoading) ...<Widget>[
            const SizedBox(height: TatuzinSpacing.md),
            const LinearProgressIndicator(),
          ],
          if (overview != null) ...<Widget>[
            const SizedBox(height: TatuzinSpacing.md),
            Wrap(
              spacing: TatuzinSpacing.sm,
              runSpacing: TatuzinSpacing.sm,
              children: <Widget>[
                _MetricChip(
                  label: 'Categorias',
                  value: '${overview.categories.length}',
                ),
                _MetricChip(
                  label: 'Produtos',
                  value: '${overview.products.length}',
                ),
                _MetricChip(
                  label: 'Variantes',
                  value: '${overview.variants.length}',
                ),
                _MetricChip(
                  label: 'Estoque total',
                  value: '${overview.totalInventoryUnits} un',
                ),
                _MetricChip(
                  label: 'Fornecedores',
                  value: '${overview.suppliers.length}',
                ),
                _MetricChip(
                  label: 'Compras abertas',
                  value: '${overview.openPurchaseCount}',
                ),
                _MetricChip(
                  label: 'Recebiveis em aberto',
                  value: CurrencyUtils.formatMoney(
                    overview.outstandingReceivablesInCents,
                  ),
                ),
                _MetricChip(
                  label: 'Caixas abertos',
                  value: '${overview.openCashSessionCount}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: _SectionCard(
          title: 'Falha ao carregar o ERP',
          action: FilledButton.tonalIcon(
            onPressed: _refreshOverview,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Tentar novamente'),
          ),
          child: Text(error.toString()),
        ),
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context, ErpOverview overview) {
    return ListView(
      children: <Widget>[
        _SectionCard(
          title: 'Categorias',
          action: FilledButton.icon(
            onPressed: _openCreateCategoryDialog,
            icon: const Icon(Icons.add_outlined),
            label: const Text('Nova categoria'),
          ),
          child: overview.categories.isEmpty
              ? const Text('Nenhuma categoria cadastrada ainda.')
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: overview.categories.map((category) {
                    return _StatusPill(
                      label: category.name,
                      value: category.active ? 'Ativa' : 'Inativa',
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Produtos',
          action: FilledButton.icon(
            onPressed: () => _openProductDialog(overview),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Novo produto'),
          ),
          child: overview.products.isEmpty
              ? const Text('Nenhum produto cadastrado no catalogo mestre.')
              : Column(
                  children: overview.products.map((product) {
                    return _RecordCard(
                      title: product.name,
                      badge: _BooleanStatusChip(isActive: product.active),
                      lines: <String>[
                        'Categoria: ${product.categoryName ?? 'Sem categoria'}',
                        'Atualizado em ${CurrencyUtils.formatDateTime(product.updatedAt)}',
                      ],
                      actions: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _openProductDialog(overview, product: product),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildVariantsTab(BuildContext context, ErpOverview overview) {
    return ListView(
      children: <Widget>[
        _SectionCard(
          title: 'Variantes',
          action: FilledButton.icon(
            onPressed: overview.products.isEmpty
                ? null
                : () => _openVariantDialog(overview),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Nova variante'),
          ),
          child: overview.variants.isEmpty
              ? const Text(
                  'Nenhuma variante cadastrada. Crie ao menos um produto antes de cadastrar variantes.',
                )
              : Column(
                  children: overview.variants.map((variant) {
                    final priceLabel = CurrencyUtils.formatMoney(
                      variant.priceInCents,
                    );
                    final promoLabel = variant.promotionalPriceInCents == null
                        ? 'Sem promocao'
                        : CurrencyUtils.formatMoney(
                            variant.promotionalPriceInCents!,
                          );

                    return _RecordCard(
                      title: variant.displayName,
                      badge: _BooleanStatusChip(isActive: variant.active),
                      lines: <String>[
                        'Produto: ${variant.productName}',
                        'SKU: ${variant.sku ?? '-'} | Codigo de barras: ${variant.barcode ?? '-'}',
                        'Cor/Tamanho: ${variant.color ?? '-'} / ${variant.size ?? '-'}',
                        'Preco base: $priceLabel | Promocional: $promoLabel',
                        'Categoria: ${variant.categoryName ?? 'Sem categoria'}',
                      ],
                      actions: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _openVariantDialog(overview, variant: variant),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab(BuildContext context, ErpOverview overview) {
    return ListView(
      children: <Widget>[
        _SectionCard(
          title: 'Saldo por variante',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: overview.variants.isEmpty
                    ? null
                    : () => _openInventoryAdjustmentDialog(overview),
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Ajustar'),
              ),
              FilledButton.tonalIcon(
                onPressed: overview.inventoryItems.isEmpty
                    ? null
                    : () => _openInventoryCountDialog(overview),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Inventario'),
              ),
            ],
          ),
          child: overview.inventoryItems.isEmpty
              ? const Text('Nenhum saldo de estoque disponivel.')
              : Column(
                  children: overview.inventoryItems.map((item) {
                    return _RecordCard(
                      title: item.variantDisplayName,
                      badge: _StatusPill(
                        label: 'Saldo',
                        value: '${item.quantityOnHand} un',
                      ),
                      lines: <String>[
                        'Produto: ${item.productName}',
                        'SKU: ${item.sku ?? '-'} | Codigo de barras: ${item.barcode ?? '-'}',
                        'Cor/Tamanho: ${item.color ?? '-'} / ${item.size ?? '-'}',
                        'Atualizado em ${CurrencyUtils.formatDateTime(item.updatedAt)}',
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSuppliersTab(BuildContext context, ErpOverview overview) {
    return ListView(
      children: <Widget>[
        _SectionCard(
          title: 'Fornecedores',
          action: FilledButton.icon(
            onPressed: _openCreateSupplierDialog,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Novo fornecedor'),
          ),
          child: overview.suppliers.isEmpty
              ? const Text('Nenhum fornecedor cadastrado ainda.')
              : Column(
                  children: overview.suppliers.map((supplier) {
                    return _RecordCard(
                      title: supplier.name,
                      lines: <String>[
                        'Telefone: ${supplier.phone ?? '-'}',
                        'Email: ${supplier.email ?? '-'}',
                        'Observacoes: ${supplier.notes ?? '-'}',
                        'Atualizado em ${CurrencyUtils.formatDateTime(supplier.updatedAt)}',
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildPurchasesTab(BuildContext context, ErpOverview overview) {
    return ListView(
      children: <Widget>[
        _SectionCard(
          title: 'Pedidos de compra',
          action: FilledButton.icon(
            onPressed: overview.suppliers.isEmpty || overview.variants.isEmpty
                ? null
                : () => _openCreatePurchaseDialog(overview),
            icon: const Icon(Icons.add_shopping_cart_outlined),
            label: const Text('Novo pedido'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (overview.suppliers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Cadastre ao menos um fornecedor para registrar compras.',
                  ),
                ),
              if (overview.variants.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Cadastre variantes antes de criar pedidos de compra.',
                  ),
                ),
              if (overview.purchases.isEmpty)
                const Text('Nenhum pedido de compra criado ainda.')
              else
                Column(
                  children: overview.purchases.map((purchase) {
                    final itemLabels = purchase.items.map((item) {
                      return '${item.variantDisplayName}: ${item.quantityReceived}/${item.quantityOrdered} recebidos';
                    }).toList();

                    return _RecordCard(
                      title: 'Pedido ${purchase.id.substring(0, 8)}',
                      badge: _PurchaseStatusChip(status: purchase.status),
                      lines: <String>[
                        'Fornecedor: ${purchase.supplierName}',
                        if ((purchase.notes ?? '').isNotEmpty)
                          'Observacoes: ${purchase.notes}',
                        'Criado em ${CurrencyUtils.formatDateTime(purchase.createdAt)}',
                        'Recebimentos: ${purchase.receipts.length}',
                        ...itemLabels,
                      ],
                      actions: <Widget>[
                        if (purchase.canReceive)
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _openReceivePurchaseDialog(purchase),
                            icon: const Icon(Icons.move_to_inbox_outlined),
                            label: const Text('Receber entrada'),
                          ),
                      ],
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceivablesTab(BuildContext context, ErpOverview overview) {
    final openTotal = CurrencyUtils.formatMoney(
      overview.outstandingReceivablesInCents,
    );

    return ListView(
      children: <Widget>[
        _SectionCard(
          title: 'Notas a receber',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Total em aberto: $openTotal. Baixas registradas aqui passam pelo backend e respeitam idempotencia.',
              ),
              const SizedBox(height: 12),
              if (overview.receivables.isEmpty)
                const Text('Nenhuma pendencia financeira consolidada ainda.')
              else
                Column(
                  children: overview.receivables.map((receivable) {
                    return _RecordCard(
                      title: 'Nota ${receivable.id.substring(0, 8)}',
                      badge: _ReceivableStatusChip(status: receivable.status),
                      lines: <String>[
                        'Venda: ${receivable.saleId.substring(0, 8)}',
                        'Cliente: ${receivable.customerId ?? '-'}',
                        'Original: ${CurrencyUtils.formatMoney(receivable.originalAmountInCents)}',
                        'Pago: ${CurrencyUtils.formatMoney(receivable.paidAmountInCents)}',
                        'Saldo: ${CurrencyUtils.formatMoney(receivable.outstandingAmountInCents)}',
                        'Emissao: ${CurrencyUtils.formatDate(receivable.issueDate)}',
                        'Vencimento: ${CurrencyUtils.formatDate(receivable.dueDate)}',
                        if ((receivable.notes ?? '').isNotEmpty)
                          'Observacoes: ${receivable.notes}',
                      ],
                      actions: <Widget>[
                        if (receivable.canSettle)
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _openReceivableSettlementDialog(receivable),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Registrar baixa'),
                          ),
                      ],
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCashTab(BuildContext context, ErpOverview overview) {
    return ListView(
      children: <Widget>[
        _SectionCard(
          title: 'Caixa consolidado',
          child: overview.cashSessions.isEmpty
              ? const Text(
                  'Nenhuma sessao de caixa sincronizada. O PDV local envia eventos de abertura, vendas, sangrias, suprimentos e fechamento pelo Sync Bridge.',
                )
              : Column(
                  children: overview.cashSessions.map((session) {
                    final settledCash =
                        session.cashSalesInCents +
                        session.receivableSettlementCashInCents;
                    final settledPix =
                        session.pixSalesInCents +
                        session.receivableSettlementPixInCents;

                    return _RecordCard(
                      title:
                          'Caixa ${session.cashSessionLocalId.substring(0, 8)}',
                      badge: _CashStatusChip(status: session.status),
                      lines: <String>[
                        'Aberto em: ${session.openedAt == null ? '-' : CurrencyUtils.formatDateTime(session.openedAt!)}',
                        'Fechado em: ${session.closedAt == null ? '-' : CurrencyUtils.formatDateTime(session.closedAt!)}',
                        'Movimentos: ${session.movementCount}',
                        'Abertura: ${CurrencyUtils.formatMoney(session.openingAmountInCents)}',
                        'Dinheiro liquidado: ${CurrencyUtils.formatMoney(settledCash)}',
                        'Pix liquidado: ${CurrencyUtils.formatMoney(settledPix)}',
                        'Vendas em nota: ${CurrencyUtils.formatMoney(session.noteSalesInCents)}',
                        'Suprimentos: ${CurrencyUtils.formatMoney(session.suppliesInCents)}',
                        'Sangrias: ${CurrencyUtils.formatMoney(session.withdrawalsInCents)}',
                        'Saldo fisico esperado: ${CurrencyUtils.formatMoney(session.expectedCashBalanceInCents)}',
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _refreshOverview() async {
    try {
      await ref.read(erpOverviewNotifierProvider.notifier).refresh();
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openCreateCategoryDialog() async {
    final result = await showDialog<_CategoryDialogResult>(
      context: context,
      builder: (dialogContext) => const _CategoryDialog(),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(erpOverviewNotifierProvider.notifier)
          .createCategory(name: result.name, active: result.active);
      _showMessage('Categoria criada com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openProductDialog(
    ErpOverview overview, {
    ErpProduct? product,
  }) async {
    final result = await showDialog<_ProductDialogResult>(
      context: context,
      builder: (dialogContext) =>
          _ProductDialog(categories: overview.categories, product: product),
    );
    if (result == null) {
      return;
    }

    try {
      final notifier = ref.read(erpOverviewNotifierProvider.notifier);
      if (product == null) {
        await notifier.createProduct(
          name: result.name,
          categoryId: result.categoryId,
          active: result.active,
        );
        _showMessage('Produto criado com sucesso.');
      } else {
        await notifier.updateProduct(
          productId: product.id,
          name: result.name,
          categoryId: result.categoryId,
          active: result.active,
        );
        _showMessage('Produto atualizado com sucesso.');
      }
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openVariantDialog(
    ErpOverview overview, {
    ErpVariant? variant,
  }) async {
    final result = await showDialog<_VariantDialogResult>(
      context: context,
      builder: (dialogContext) =>
          _VariantDialog(products: overview.products, variant: variant),
    );
    if (result == null) {
      return;
    }

    try {
      final notifier = ref.read(erpOverviewNotifierProvider.notifier);
      if (variant == null) {
        await notifier.createVariant(
          productId: result.productId,
          barcode: result.barcode,
          sku: result.sku,
          color: result.color,
          size: result.size,
          priceInCents: result.priceInCents,
          promotionalPriceInCents: result.promotionalPriceInCents,
          active: result.active,
        );
        _showMessage('Variante criada com sucesso.');
      } else {
        await notifier.updateVariant(
          variantId: variant.id,
          barcode: result.barcode,
          sku: result.sku,
          color: result.color,
          size: result.size,
          priceInCents: result.priceInCents,
          promotionalPriceInCents: result.promotionalPriceInCents,
          active: result.active,
        );
        _showMessage('Variante atualizada com sucesso.');
      }
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openCreateSupplierDialog() async {
    final result = await showDialog<_SupplierDialogResult>(
      context: context,
      builder: (dialogContext) => const _SupplierDialog(),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(erpOverviewNotifierProvider.notifier)
          .createSupplier(
            name: result.name,
            phone: result.phone,
            email: result.email,
            notes: result.notes,
          );
      _showMessage('Fornecedor criado com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openCreatePurchaseDialog(ErpOverview overview) async {
    final result = await showDialog<_PurchaseDialogResult>(
      context: context,
      builder: (dialogContext) => _PurchaseDialog(
        suppliers: overview.suppliers,
        variants: overview.variants,
      ),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(erpOverviewNotifierProvider.notifier)
          .createPurchase(
            supplierId: result.supplierId,
            notes: result.notes,
            items: result.items,
          );
      _showMessage('Pedido de compra criado com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openReceivePurchaseDialog(ErpPurchase purchase) async {
    final result = await showDialog<_ReceivePurchaseDialogResult>(
      context: context,
      builder: (dialogContext) => _ReceivePurchaseDialog(purchase: purchase),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(erpOverviewNotifierProvider.notifier)
          .receivePurchase(purchaseId: purchase.id, items: result.items);
      _showMessage('Recebimento registrado com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openInventoryAdjustmentDialog(ErpOverview overview) async {
    final result = await showDialog<_InventoryAdjustmentDialogResult>(
      context: context,
      builder: (dialogContext) =>
          _InventoryAdjustmentDialog(variants: overview.variants),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(erpOverviewNotifierProvider.notifier)
          .createInventoryAdjustment(
            variantId: result.variantId,
            quantityDelta: result.quantityDelta,
            reason: result.reason,
          );
      _showMessage('Ajuste de estoque registrado com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openInventoryCountDialog(ErpOverview overview) async {
    final result = await showDialog<_InventoryCountDialogResult>(
      context: context,
      builder: (dialogContext) =>
          _InventoryCountDialog(items: overview.inventoryItems),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(erpOverviewNotifierProvider.notifier)
          .recordInventoryCount(items: result.items);
      _showMessage('Inventario registrado com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _openReceivableSettlementDialog(
    ErpReceivableNote receivable,
  ) async {
    final result = await showDialog<_ReceivableSettlementDialogResult>(
      context: context,
      builder: (dialogContext) =>
          _ReceivableSettlementDialog(receivable: receivable),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(erpOverviewNotifierProvider.notifier)
          .settleReceivable(
            receivableId: receivable.id,
            amountInCents: result.amountInCents,
            settlementMethod: result.settlementMethod,
          );
      _showMessage('Baixa da nota registrada com sucesso.');
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

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.title,
    required this.lines,
    this.badge,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<String> lines;
  final Widget? badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TatuzinSpacing.sm),
      child: AppRecordCard(
        title: title,
        lines: lines,
        badge: badge,
        actions: actions,
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppMetricTile(label: label, value: value, tone: AppTone.info);
  }
}

AppTone _erpToneForStatusLabel(String value) {
  switch (value.toLowerCase()) {
    case 'ativa':
    case 'ativo':
    case 'recebido':
    case 'aberto':
      return AppTone.success;
    case 'inativa':
    case 'inativo':
    case 'fechado':
      return AppTone.info;
    case 'parcial':
      return AppTone.warning;
    default:
      return AppTone.info;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppMetricTile(
      label: label,
      value: value,
      tone: _erpToneForStatusLabel(value),
    );
  }
}

class _BooleanStatusChip extends StatelessWidget {
  const _BooleanStatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AppStatusBadge(
      label: isActive ? 'Ativo' : 'Inativo',
      tone: isActive ? AppTone.success : AppTone.info,
    );
  }
}

class _PurchaseStatusChip extends StatelessWidget {
  const _PurchaseStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'pending' => 'Pendente',
      'partially_received' => 'Parcial',
      'received' => 'Recebido',
      _ => status,
    };
    final tone = switch (status) {
      'pending' => AppTone.warning,
      'partially_received' => AppTone.info,
      'received' => AppTone.success,
      _ => AppTone.info,
    };

    return AppStatusBadge(label: label, tone: tone);
  }
}

AppTone _erpToneForReceivableStatus(String status) {
  switch (status) {
    case 'pending':
      return AppTone.note;
    case 'partially_paid':
      return AppTone.warning;
    case 'paid':
      return AppTone.success;
    case 'overdue':
      return AppTone.danger;
    case 'canceled':
    default:
      return AppTone.info;
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
    return AppStatusBadge(
      label: label,
      tone: _erpToneForReceivableStatus(status),
    );
  }
}

class _CashStatusChip extends StatelessWidget {
  const _CashStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isClosed = status == 'closed';
    return AppStatusBadge(
      label: isClosed ? 'Fechado' : 'Aberto',
      tone: isClosed ? AppTone.info : AppTone.success,
    );
  }
}

class _CategoryDialogResult {
  const _CategoryDialogResult({required this.name, required this.active});

  final String name;
  final bool active;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameController;
  bool _active = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Categoria ativa'),
              value: _active,
              onChanged: (value) {
                setState(() {
                  _active = value;
                });
              },
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
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Informe o nome da categoria.';
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(_CategoryDialogResult(name: name, active: _active));
  }
}

class _ProductDialogResult {
  const _ProductDialogResult({
    required this.name,
    required this.categoryId,
    required this.active,
  });

  final String name;
  final String? categoryId;
  final bool active;
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.categories, this.product});

  final List<ErpCategory> categories;
  final ErpProduct? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _nameController;
  late bool _active;
  String? _categoryId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _active = widget.product?.active ?? true;
    _categoryId = widget.product?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar produto' : 'Novo produto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome do produto'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sem categoria'),
                ),
                ...widget.categories.map((category) {
                  return DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _categoryId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Produto ativo'),
              value: _active,
              onChanged: (value) {
                setState(() {
                  _active = value;
                });
              },
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
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Informe o nome do produto.';
      });
      return;
    }

    Navigator.of(context).pop(
      _ProductDialogResult(
        name: name,
        categoryId: _categoryId,
        active: _active,
      ),
    );
  }
}

class _VariantDialogResult {
  const _VariantDialogResult({
    required this.productId,
    this.barcode,
    this.sku,
    this.color,
    this.size,
    required this.priceInCents,
    this.promotionalPriceInCents,
    required this.active,
  });

  final String productId;
  final String? barcode;
  final String? sku;
  final String? color;
  final String? size;
  final int priceInCents;
  final int? promotionalPriceInCents;
  final bool active;
}

class _VariantDialog extends StatefulWidget {
  const _VariantDialog({required this.products, this.variant});

  final List<ErpProduct> products;
  final ErpVariant? variant;

  @override
  State<_VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<_VariantDialog> {
  late final TextEditingController _barcodeController;
  late final TextEditingController _skuController;
  late final TextEditingController _colorController;
  late final TextEditingController _sizeController;
  late final TextEditingController _priceController;
  late final TextEditingController _promoController;
  late bool _active;
  String? _productId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final variant = widget.variant;
    _barcodeController = TextEditingController(text: variant?.barcode ?? '');
    _skuController = TextEditingController(text: variant?.sku ?? '');
    _colorController = TextEditingController(text: variant?.color ?? '');
    _sizeController = TextEditingController(text: variant?.size ?? '');
    _priceController = TextEditingController(
      text: variant == null
          ? ''
          : CurrencyUtils.formatMoney(
              variant.priceInCents,
            ).replaceAll('R\$ ', ''),
    );
    _promoController = TextEditingController(
      text: variant?.promotionalPriceInCents == null
          ? ''
          : CurrencyUtils.formatMoney(
              variant!.promotionalPriceInCents!,
            ).replaceAll('R\$ ', ''),
    );
    _active = variant?.active ?? true;
    _productId = variant?.productId;
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _skuController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    _priceController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.variant != null;
    final currentProduct = widget.products.firstWhere(
      (product) => product.id == _productId,
      orElse: () => widget.products.first,
    );

    return AlertDialog(
      title: Text(isEditing ? 'Editar variante' : 'Nova variante'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Produto: ${currentProduct.name}'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: _productId,
                  decoration: const InputDecoration(labelText: 'Produto'),
                  items: widget.products.map((product) {
                    return DropdownMenuItem<String>(
                      value: product.id,
                      child: Text(product.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _productId = value;
                    });
                  },
                ),
              ),
            TextField(
              controller: _barcodeController,
              decoration: const InputDecoration(labelText: 'Codigo de barras'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skuController,
              decoration: const InputDecoration(labelText: 'SKU'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(labelText: 'Cor'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sizeController,
              decoration: const InputDecoration(labelText: 'Tamanho'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Preco base'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Preco promocional (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Variante ativa'),
              value: _active,
              onChanged: (value) {
                setState(() {
                  _active = value;
                });
              },
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
    if (_productId == null || _productId!.isEmpty) {
      setState(() {
        _errorMessage = 'Selecione o produto da variante.';
      });
      return;
    }

    final priceRaw = _priceController.text.trim();
    if (priceRaw.isEmpty) {
      setState(() {
        _errorMessage = 'Informe o preco base da variante.';
      });
      return;
    }

    try {
      final priceInCents = CurrencyUtils.parseCurrencyToCents(priceRaw);
      final promoRaw = _promoController.text.trim();
      final promotionalPriceInCents = promoRaw.isEmpty
          ? null
          : CurrencyUtils.parseCurrencyToCents(promoRaw);

      Navigator.of(context).pop(
        _VariantDialogResult(
          productId: _productId!,
          barcode: _normalizeOptional(_barcodeController.text),
          sku: _normalizeOptional(_skuController.text),
          color: _normalizeOptional(_colorController.text),
          size: _normalizeOptional(_sizeController.text),
          priceInCents: priceInCents,
          promotionalPriceInCents: promotionalPriceInCents,
          active: _active,
        ),
      );
    } on Object {
      setState(() {
        _errorMessage = 'Informe valores monetarios validos para a variante.';
      });
    }
  }
}

class _SupplierDialogResult {
  const _SupplierDialogResult({
    required this.name,
    this.phone,
    this.email,
    this.notes,
  });

  final String name;
  final String? phone;
  final String? email;
  final String? notes;
}

class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog();

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _notesController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo fornecedor'),
      content: SingleChildScrollView(
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
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Informe o nome do fornecedor.';
      });
      return;
    }

    Navigator.of(context).pop(
      _SupplierDialogResult(
        name: name,
        phone: _normalizeOptional(_phoneController.text),
        email: _normalizeOptional(_emailController.text),
        notes: _normalizeOptional(_notesController.text),
      ),
    );
  }
}

class _PurchaseDialogResult {
  const _PurchaseDialogResult({
    required this.supplierId,
    required this.items,
    this.notes,
  });

  final String supplierId;
  final String? notes;
  final List<ErpPurchaseDraftItem> items;
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({required this.suppliers, required this.variants});

  final List<ErpSupplier> suppliers;
  final List<ErpVariant> variants;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  late final TextEditingController _notesController;
  late final List<_PurchaseLineDraft> _lines;
  String? _supplierId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _lines = <_PurchaseLineDraft>[_PurchaseLineDraft()];
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo pedido de compra'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _supplierId,
                decoration: const InputDecoration(labelText: 'Fornecedor'),
                items: widget.suppliers.map((supplier) {
                  return DropdownMenuItem<String>(
                    value: supplier.id,
                    child: Text(supplier.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _supplierId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Observacoes'),
              ),
              const SizedBox(height: 16),
              Text(
                'Itens do pedido',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < _lines.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: <Widget>[
                          DropdownButtonFormField<String>(
                            initialValue: _lines[index].variantId,
                            decoration: InputDecoration(
                              labelText: 'Variante ${index + 1}',
                            ),
                            items: widget.variants.map((variant) {
                              return DropdownMenuItem<String>(
                                value: variant.id,
                                child: Text(variant.displayName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _lines[index].variantId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: _lines[index].quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantidade',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _lines[index].costController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Custo unitario',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_lines.length > 1) ...<Widget>[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _removeLine(index),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remover item'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add_outlined),
                label: const Text('Adicionar item'),
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
        FilledButton(onPressed: _submit, child: const Text('Salvar pedido')),
      ],
    );
  }

  void _addLine() {
    setState(() {
      _lines.add(_PurchaseLineDraft());
    });
  }

  void _removeLine(int index) {
    setState(() {
      final removed = _lines.removeAt(index);
      removed.dispose();
    });
  }

  void _submit() {
    if (_supplierId == null || _supplierId!.isEmpty) {
      setState(() {
        _errorMessage = 'Selecione o fornecedor do pedido.';
      });
      return;
    }

    final items = <ErpPurchaseDraftItem>[];

    try {
      for (final line in _lines) {
        if (line.variantId == null || line.variantId!.isEmpty) {
          throw const _DialogValidationException(
            'Selecione a variante de todos os itens.',
          );
        }

        final quantityOrdered = int.tryParse(
          line.quantityController.text.trim(),
        );
        if (quantityOrdered == null || quantityOrdered <= 0) {
          throw const _DialogValidationException(
            'Informe quantidades validas para todos os itens.',
          );
        }

        final unitCostInCents = CurrencyUtils.parseCurrencyToCents(
          line.costController.text.trim(),
        );
        if (unitCostInCents <= 0) {
          throw const _DialogValidationException(
            'O custo unitario precisa ser maior que zero.',
          );
        }

        items.add(
          ErpPurchaseDraftItem(
            variantId: line.variantId!,
            quantityOrdered: quantityOrdered,
            unitCostInCents: unitCostInCents,
          ),
        );
      }
    } on _DialogValidationException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
      return;
    } on Object {
      setState(() {
        _errorMessage = 'Revise as quantidades e custos do pedido.';
      });
      return;
    }

    Navigator.of(context).pop(
      _PurchaseDialogResult(
        supplierId: _supplierId!,
        notes: _normalizeOptional(_notesController.text),
        items: items,
      ),
    );
  }
}

class _ReceivePurchaseDialogResult {
  const _ReceivePurchaseDialogResult({required this.items});

  final List<ErpPurchaseReceiptDraftItem> items;
}

class _ReceivePurchaseDialog extends StatefulWidget {
  const _ReceivePurchaseDialog({required this.purchase});

  final ErpPurchase purchase;

  @override
  State<_ReceivePurchaseDialog> createState() => _ReceivePurchaseDialogState();
}

class _ReceivePurchaseDialogState extends State<_ReceivePurchaseDialog> {
  late final List<_ReceiveLineDraft> _lines;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _lines = widget.purchase.items
        .where((item) => item.pendingQuantity > 0)
        .map(
          (item) => _ReceiveLineDraft(
            purchaseItemId: item.id,
            label: item.variantDisplayName,
            pendingQuantity: item.pendingQuantity,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar recebimento'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Fornecedor: ${widget.purchase.supplierName}'),
              const SizedBox(height: 12),
              if (_lines.isEmpty)
                const Text('Este pedido ja foi recebido integralmente.')
              else
                for (final line in _lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              line.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pendente: ${line.pendingQuantity} unidade(s)',
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: line.quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade recebida agora',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
          onPressed: _lines.isEmpty ? null : _submit,
          child: const Text('Registrar'),
        ),
      ],
    );
  }

  void _submit() {
    final items = <ErpPurchaseReceiptDraftItem>[];

    for (final line in _lines) {
      final rawValue = line.quantityController.text.trim();
      if (rawValue.isEmpty) {
        continue;
      }

      final quantityReceived = int.tryParse(rawValue);
      if (quantityReceived == null || quantityReceived < 0) {
        setState(() {
          _errorMessage = 'Use apenas quantidades inteiras e positivas.';
        });
        return;
      }
      if (quantityReceived > line.pendingQuantity) {
        setState(() {
          _errorMessage = 'Nenhuma linha pode exceder a quantidade pendente.';
        });
        return;
      }
      if (quantityReceived == 0) {
        continue;
      }

      items.add(
        ErpPurchaseReceiptDraftItem(
          purchaseItemId: line.purchaseItemId,
          quantityReceived: quantityReceived,
        ),
      );
    }

    if (items.isEmpty) {
      setState(() {
        _errorMessage = 'Informe ao menos uma quantidade recebida.';
      });
      return;
    }

    Navigator.of(context).pop(_ReceivePurchaseDialogResult(items: items));
  }
}

class _InventoryAdjustmentDialogResult {
  const _InventoryAdjustmentDialogResult({
    required this.variantId,
    required this.quantityDelta,
    this.reason,
  });

  final String variantId;
  final int quantityDelta;
  final String? reason;
}

class _InventoryAdjustmentDialog extends StatefulWidget {
  const _InventoryAdjustmentDialog({required this.variants});

  final List<ErpVariant> variants;

  @override
  State<_InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends State<_InventoryAdjustmentDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  String? _variantId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _reasonController = TextEditingController(text: 'manual_adjustment');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajuste de estoque'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _variantId,
                decoration: const InputDecoration(labelText: 'Variante'),
                items: widget.variants.map((variant) {
                  return DropdownMenuItem<String>(
                    value: variant.id,
                    child: Text(variant.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _variantId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Delta de estoque',
                  helperText:
                      'Use positivo para entrada e negativo para saida.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Motivo'),
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
        FilledButton(onPressed: _submit, child: const Text('Registrar')),
      ],
    );
  }

  void _submit() {
    final quantityDelta = int.tryParse(_quantityController.text.trim());
    if (_variantId == null || _variantId!.isEmpty) {
      setState(() {
        _errorMessage = 'Selecione a variante.';
      });
      return;
    }
    if (quantityDelta == null || quantityDelta == 0) {
      setState(() {
        _errorMessage = 'Informe um delta inteiro diferente de zero.';
      });
      return;
    }

    Navigator.of(context).pop(
      _InventoryAdjustmentDialogResult(
        variantId: _variantId!,
        quantityDelta: quantityDelta,
        reason: _normalizeOptional(_reasonController.text),
      ),
    );
  }
}

class _InventoryCountDialogResult {
  const _InventoryCountDialogResult({required this.items});

  final List<ErpInventoryCountDraftItem> items;
}

class _InventoryCountDialog extends StatefulWidget {
  const _InventoryCountDialog({required this.items});

  final List<ErpInventoryItem> items;

  @override
  State<_InventoryCountDialog> createState() => _InventoryCountDialogState();
}

class _InventoryCountDialogState extends State<_InventoryCountDialog> {
  late final List<_InventoryCountLineDraft> _lines;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _lines = widget.items
        .map(
          (item) => _InventoryCountLineDraft(
            variantId: item.variantId,
            label: item.variantDisplayName,
            currentQuantity: item.quantityOnHand,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inventario rapido'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final line in _lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              line.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('Saldo atual: ${line.currentQuantity} un'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: line.quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Fisico',
                          ),
                        ),
                      ),
                    ],
                  ),
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
        FilledButton(onPressed: _submit, child: const Text('Registrar')),
      ],
    );
  }

  void _submit() {
    final items = <ErpInventoryCountDraftItem>[];
    for (final line in _lines) {
      final countedQuantity = int.tryParse(line.quantityController.text.trim());
      if (countedQuantity == null || countedQuantity < 0) {
        setState(() {
          _errorMessage = 'Use quantidades inteiras e nao negativas.';
        });
        return;
      }

      items.add(
        ErpInventoryCountDraftItem(
          variantId: line.variantId,
          countedQuantity: countedQuantity,
        ),
      );
    }

    Navigator.of(context).pop(_InventoryCountDialogResult(items: items));
  }
}

class _ReceivableSettlementDialogResult {
  const _ReceivableSettlementDialogResult({
    required this.amountInCents,
    required this.settlementMethod,
  });

  final int amountInCents;
  final String settlementMethod;
}

class _ReceivableSettlementDialog extends StatefulWidget {
  const _ReceivableSettlementDialog({required this.receivable});

  final ErpReceivableNote receivable;

  @override
  State<_ReceivableSettlementDialog> createState() =>
      _ReceivableSettlementDialogState();
}

class _ReceivableSettlementDialogState
    extends State<_ReceivableSettlementDialog> {
  late final TextEditingController _amountController;
  String _settlementMethod = 'cash';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: CurrencyUtils.formatMoney(
        widget.receivable.outstandingAmountInCents,
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar baixa'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Saldo atual: ${CurrencyUtils.formatMoney(widget.receivable.outstandingAmountInCents)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Valor da baixa'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _settlementMethod,
              decoration: const InputDecoration(labelText: 'Metodo'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'cash',
                  child: Text('Dinheiro'),
                ),
                DropdownMenuItem<String>(value: 'pix', child: Text('Pix')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _settlementMethod = value;
                });
              },
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
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Registrar')),
      ],
    );
  }

  void _submit() {
    try {
      final amountInCents = CurrencyUtils.parseCurrencyToCents(
        _amountController.text.trim(),
      );
      if (amountInCents <= 0) {
        throw const _DialogValidationException(
          'Informe um valor maior que zero.',
        );
      }
      if (amountInCents > widget.receivable.outstandingAmountInCents) {
        throw const _DialogValidationException(
          'A baixa nao pode exceder o saldo em aberto.',
        );
      }
      Navigator.of(context).pop(
        _ReceivableSettlementDialogResult(
          amountInCents: amountInCents,
          settlementMethod: _settlementMethod,
        ),
      );
    } on _DialogValidationException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } on Object {
      setState(() {
        _errorMessage = 'Informe um valor monetario valido.';
      });
    }
  }
}

class _PurchaseLineDraft {
  _PurchaseLineDraft()
    : quantityController = TextEditingController(text: '1'),
      costController = TextEditingController();

  String? variantId;
  final TextEditingController quantityController;
  final TextEditingController costController;

  void dispose() {
    quantityController.dispose();
    costController.dispose();
  }
}

class _ReceiveLineDraft {
  _ReceiveLineDraft({
    required this.purchaseItemId,
    required this.label,
    required this.pendingQuantity,
  }) : quantityController = TextEditingController(text: '$pendingQuantity');

  final String purchaseItemId;
  final String label;
  final int pendingQuantity;
  final TextEditingController quantityController;

  void dispose() {
    quantityController.dispose();
  }
}

class _InventoryCountLineDraft {
  _InventoryCountLineDraft({
    required this.variantId,
    required this.label,
    required this.currentQuantity,
  }) : quantityController = TextEditingController(text: '$currentQuantity');

  final String variantId;
  final String label;
  final int currentQuantity;
  final TextEditingController quantityController;

  void dispose() {
    quantityController.dispose();
  }
}

class _DialogValidationException implements Exception {
  const _DialogValidationException(this.message);

  final String message;
}

String? _normalizeOptional(String rawValue) {
  final trimmed = rawValue.trim();
  return trimmed.isEmpty ? null : trimmed;
}
