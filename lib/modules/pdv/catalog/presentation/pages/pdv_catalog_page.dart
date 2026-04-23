import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../../../../core/permissions/domain/entities/app_role.dart';
import '../../../../../core/ui/theme/app_theme_tokens.dart';
import '../../../../../core/ui/widgets/app_metric_tile.dart';
import '../../../../../core/ui/widgets/app_section_card.dart';
import '../../../../../core/ui/widgets/app_status_badge.dart';
import '../../../../../core/ui/widgets/protected_module_scaffold.dart';
import '../../../../../core/utils/currency_utils.dart';
import '../../../cart/application/notifiers/cart_notifier.dart';
import '../../../cart/domain/entities/applied_discount.dart';
import '../../../cart/domain/entities/cart.dart';
import '../../../cart/domain/entities/discount_type.dart';
import '../../../cash_register/application/notifiers/cash_register_notifier.dart';
import '../../../cash_register/domain/entities/cash_movement_type.dart';
import '../../../cash_register/domain/entities/cash_session_summary.dart';
import '../../../checkout/application/notifiers/checkout_notifier.dart';
import '../../../checkout/application/dtos/checkout_request.dart';
import '../../../checkout/application/dtos/checkout_result.dart';
import '../../../payments/domain/entities/payment_method.dart';
import '../../../payments/presentation/providers/payment_providers.dart';
import '../../../quick_customer/domain/entities/quick_customer.dart';
import '../../../quick_customer/presentation/providers/quick_customer_providers.dart';
import '../../../receipts/presentation/providers/receipt_providers.dart';
import '../../../local_dashboard/application/dtos/local_dashboard_snapshot.dart';
import '../../../local_dashboard/domain/entities/recent_local_sale.dart';
import '../../../local_dashboard/presentation/providers/local_dashboard_providers.dart';
import '../../application/usecases/load_sale_catalog_usecase.dart';
import '../../domain/entities/product_variant_sale_snapshot.dart';
import '../providers/catalog_providers.dart';

class PdvCatalogPage extends ConsumerStatefulWidget {
  const PdvCatalogPage({super.key});

  @override
  ConsumerState<PdvCatalogPage> createState() => _PdvCatalogPageState();
}

class _PdvCatalogPageState extends ConsumerState<PdvCatalogPage> {
  late final TextEditingController _searchController;
  late final TextEditingController _openingAmountController;
  late final TextEditingController _movementAmountController;
  late final TextEditingController _movementNotesController;
  late final TextEditingController _discountController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _amountReceivedController;
  late final TextEditingController _noteDescriptionController;

  String? _selectedCategoryName;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  DiscountType _selectedDiscountType = DiscountType.value;
  CashMovementType _selectedMovementType = CashMovementType.supply;
  DateTime? _selectedDueDate;
  bool _pixConfirmedManually = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _openingAmountController = TextEditingController(text: '100,00');
    _movementAmountController = TextEditingController();
    _movementNotesController = TextEditingController();
    _discountController = TextEditingController();
    _customerNameController = TextEditingController();
    _customerPhoneController = TextEditingController();
    _amountReceivedController = TextEditingController();
    _noteDescriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _openingAmountController.dispose();
    _movementAmountController.dispose();
    _movementNotesController.dispose();
    _discountController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _amountReceivedController.dispose();
    _noteDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionNotifierProvider).asData?.value;

    ref.listen<AsyncValue<CheckoutResult?>>(checkoutNotifierProvider, (
      previous,
      next,
    ) {
      final previousSaleId = previous?.asData?.value?.sale.localId;
      final currentResult = next.asData?.value;

      if (next.hasError && previous?.error != next.error) {
        _showMessage(next.error.toString(), isError: true);
      }

      if (currentResult != null &&
          currentResult.sale.localId != previousSaleId) {
        ref.read(cartNotifierProvider.notifier).clear();
        ref.read(cashRegisterNotifierProvider.notifier).refresh();
        ref.invalidate(localDashboardSnapshotProvider);
        _resetCheckoutFormAfterSuccess();
        _showMessage(
          'Venda salva localmente. Comprovante: ${currentResult.receipt.pdfPath}',
        );
      }
    });

    ref.listen<AsyncValue<CashSessionSummary?>>(cashRegisterNotifierProvider, (
      previous,
      next,
    ) {
      if (next.hasError && previous?.error != next.error) {
        _showMessage(next.error.toString(), isError: true);
      }
      if (previous?.asData?.value != next.asData?.value) {
        ref.invalidate(localDashboardSnapshotProvider);
      }
    });

    final cart = ref.watch(cartNotifierProvider);
    final cashState = ref.watch(cashRegisterNotifierProvider);
    final checkoutState = ref.watch(checkoutNotifierProvider);
    final cashSummary = cashState.asData?.value;
    final dashboardState = cashSummary == null
        ? null
        : ref.watch(
            localDashboardSnapshotProvider(cashSummary.session.localId),
          );
    final pixPayload = session == null
        ? null
        : ref
              .read(pixPayloadServiceProvider)
              .buildManualPayload(
                totalInCents: cart.totalInCents,
                companyName: session.companyContext.companyName,
                deviceId: session.deviceRegistration.deviceId,
              );

    final catalogState = ref.watch(
      saleCatalogProvider(
        CatalogFilter(
          query: _searchController.text,
          categoryName: _selectedCategoryName,
        ),
      ),
    );

    final customerQuery = _customerPhoneController.text.trim().isNotEmpty
        ? _customerPhoneController.text.trim()
        : _customerNameController.text.trim();
    final quickCustomersState = ref.watch(
      quickCustomerSearchProvider(customerQuery),
    );

    return ProtectedModuleScaffold(
      title: 'PDV Local',
      description: 'Catalogo local, carrinho, caixa e checkout offline.',
      allowedRoles: const <AppRole>{
        AppRole.admin,
        AppRole.manager,
        AppRole.seller,
        AppRole.cashier,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1080;
          final catalogSection = _buildCatalogSection(context, catalogState);
          final sidePanel = _buildSidePanel(
            context,
            cart: cart,
            cashState: cashState,
            dashboardState: dashboardState,
            checkoutState: checkoutState,
            quickCustomersState: quickCustomersState,
            pixPayload: pixPayload,
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(child: catalogSection),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(child: sidePanel),
                ),
              ],
            );
          }

          return ListView(
            children: <Widget>[
              catalogSection,
              const SizedBox(height: 24),
              sidePanel,
            ],
          );
        },
      ),
    );
  }

  Widget _buildCatalogSection(
    BuildContext context,
    AsyncValue<SaleCatalogView> catalogState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppSectionCard(
          title: 'Catalogo de venda',
          subtitle:
              'Busca local por nome, codigo de barras ou SKU. Os produtos abaixo vivem no SQLite do dispositivo.',
          tone: AppTone.info,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar item',
              hintText: 'Nome, codigo de barras ou SKU',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: TatuzinSpacing.md),
        catalogState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) => _SectionCard(
            title: 'Falha ao carregar catalogo',
            child: Text(error.toString()),
          ),
          data: (catalog) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _selectedCategoryName == null,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryName = null;
                        });
                      },
                    ),
                    for (final category in catalog.categories)
                      ChoiceChip(
                        label: Text(category.name),
                        selected: _selectedCategoryName == category.name,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategoryName =
                                _selectedCategoryName == category.name
                                ? null
                                : category.name;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (catalog.variants.isEmpty)
                  _SectionCard(
                    title: 'Nenhum item encontrado',
                    child: const Text(
                      'Ajuste a busca ou troque a categoria para encontrar produtos.',
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 640
                          ? 2
                          : 1;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: catalog.variants.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 220,
                        ),
                        itemBuilder: (context, index) {
                          final variant = catalog.variants[index];
                          return _ProductCard(
                            variant: variant,
                            onAdd: () {
                              ref
                                  .read(cartNotifierProvider.notifier)
                                  .addVariant(variant);
                            },
                          );
                        },
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSidePanel(
    BuildContext context, {
    required Cart cart,
    required AsyncValue<CashSessionSummary?> cashState,
    required AsyncValue<LocalDashboardSnapshot>? dashboardState,
    required AsyncValue<CheckoutResult?> checkoutState,
    required AsyncValue<List<QuickCustomer>> quickCustomersState,
    required String? pixPayload,
  }) {
    final cashSummary = cashState.asData?.value;
    final lastCheckoutResult = checkoutState.asData?.value;
    final cashReceived = _parseCurrencyOrZero(_amountReceivedController.text);
    final computedChange = _selectedPaymentMethod == PaymentMethod.cash
        ? (cashReceived - cart.totalInCents).clamp(0, cashReceived)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildCashSection(context, cashState),
        if (dashboardState != null) ...<Widget>[
          const SizedBox(height: 16),
          _buildLocalIndicatorsSection(context, dashboardState),
        ],
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Carrinho',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (cart.items.isEmpty)
                const Text('Nenhum item no carrinho ainda.')
              else
                ...cart.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.variant.displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (item.variant.subtitle.isNotEmpty)
                                Text(item.variant.subtitle),
                              Text(
                                CurrencyUtils.formatMoney(
                                  item.unitPriceInCents,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: () {
                                ref
                                    .read(cartNotifierProvider.notifier)
                                    .decrementItem(item.variant.localId);
                              },
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              onPressed: () {
                                ref
                                    .read(cartNotifierProvider.notifier)
                                    .incrementItem(item.variant.localId);
                              },
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            IconButton(
                              onPressed: () {
                                ref
                                    .read(cartNotifierProvider.notifier)
                                    .removeItem(item.variant.localId);
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(),
              Text(
                'Itens: ${cart.totalItems}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                'Subtotal: ${CurrencyUtils.formatMoney(cart.subtotalInCents)}',
              ),
              Text(
                'Desconto: ${CurrencyUtils.formatMoney(cart.discountInCents)}',
              ),
              Text(
                'Total: ${CurrencyUtils.formatMoney(cart.totalInCents)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('Desconto', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<DiscountType>(
                segments: const <ButtonSegment<DiscountType>>[
                  ButtonSegment<DiscountType>(
                    value: DiscountType.value,
                    label: Text('Valor'),
                  ),
                  ButtonSegment<DiscountType>(
                    value: DiscountType.percentage,
                    label: Text('Percentual'),
                  ),
                ],
                selected: <DiscountType>{_selectedDiscountType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedDiscountType = selection.first;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _selectedDiscountType == DiscountType.value
                            ? 'Valor do desconto'
                            : 'Percentual',
                        hintText: _selectedDiscountType == DiscountType.value
                            ? '10,00'
                            : '5',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: cart.items.isEmpty ? null : _applyDiscount,
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
              if (cart.discount != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () {
                      _discountController.clear();
                      ref
                          .read(cartNotifierProvider.notifier)
                          .applyDiscount(null);
                    },
                    child: const Text('Remover desconto'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Cliente rapido',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(labelText: 'Nome do cliente'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
                onChanged: (_) => setState(() {}),
              ),
              if (quickCustomersState.asData?.value.isNotEmpty ==
                  true) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Clientes encontrados localmente',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ...quickCustomersState.asData!.value.map(
                  (customer) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(customer.name),
                    subtitle: Text(customer.phone),
                    trailing: const Icon(Icons.north_west),
                    onTap: () => _fillQuickCustomer(customer),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Checkout',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SegmentedButton<PaymentMethod>(
                segments: const <ButtonSegment<PaymentMethod>>[
                  ButtonSegment<PaymentMethod>(
                    value: PaymentMethod.cash,
                    label: Text('Dinheiro'),
                  ),
                  ButtonSegment<PaymentMethod>(
                    value: PaymentMethod.pix,
                    label: Text('Pix'),
                  ),
                  ButtonSegment<PaymentMethod>(
                    value: PaymentMethod.note,
                    label: Text('Nota'),
                  ),
                ],
                selected: <PaymentMethod>{_selectedPaymentMethod},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedPaymentMethod = selection.first;
                    if (_selectedPaymentMethod != PaymentMethod.note) {
                      _selectedDueDate = null;
                    }
                    if (_selectedPaymentMethod != PaymentMethod.pix) {
                      _pixConfirmedManually = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_selectedPaymentMethod == PaymentMethod.cash) ...<Widget>[
                TextField(
                  controller: _amountReceivedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor recebido',
                    hintText: '0,00',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text('Troco: ${CurrencyUtils.formatMoney(computedChange)}'),
              ],
              if (_selectedPaymentMethod == PaymentMethod.pix)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (pixPayload != null) ...<Widget>[
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: QrImageView(
                              data: pixPayload,
                              size: 180,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        pixPayload,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _copyPixPayload(pixPayload),
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Copiar codigo Pix'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    CheckboxListTile(
                      value: _pixConfirmedManually,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pix confirmado manualmente'),
                      subtitle: const Text(
                        'O operador valida o pagamento e so depois conclui a venda.',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _pixConfirmedManually = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              if (_selectedPaymentMethod == PaymentMethod.note) ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _selectedDueDate == null
                        ? 'Selecionar vencimento'
                        : 'Vence em ${CurrencyUtils.formatDate(_selectedDueDate!)}',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total pendente: ${CurrencyUtils.formatMoney(cart.totalInCents)}',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Observacao da nota',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nesta fase, nota exige cliente identificado e nao gera troco.',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    cart.items.isEmpty ||
                        cashSummary == null ||
                        checkoutState.isLoading
                    ? null
                    : _submitCheckout,
                icon: checkoutState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale_outlined),
                label: Text(
                  checkoutState.isLoading
                      ? 'Concluindo...'
                      : 'Concluir venda offline',
                ),
              ),
            ],
          ),
        ),
        if (dashboardState != null) ...<Widget>[
          const SizedBox(height: 16),
          _buildRecentSalesSection(context, dashboardState),
        ],
        if (lastCheckoutResult != null) ...<Widget>[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Ultimo comprovante',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Venda: ${lastCheckoutResult.sale.localId}'),
                Text('Arquivo: ${lastCheckoutResult.receipt.pdfPath}'),
                Text(
                  'Pagamento: ${_paymentMethodLabel(lastCheckoutResult.payment.method)}',
                ),
                if (lastCheckoutResult.paymentTerm != null)
                  Text(
                    'Vencimento: ${CurrencyUtils.formatDate(lastCheckoutResult.paymentTerm!.dueDate)}',
                  ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      _shareReceiptPdf(lastCheckoutResult.receipt.pdfPath),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Compartilhar PDF'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCashSection(
    BuildContext context,
    AsyncValue<CashSessionSummary?> cashState,
  ) {
    final cashSummary = cashState.asData?.value;

    if (cashState.isLoading && cashSummary == null) {
      return const _SectionCard(
        title: 'Caixa',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (cashSummary == null) {
      return _SectionCard(
        title: 'Abrir caixa',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'O PDV exige caixa aberto antes de registrar vendas na sessao.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _openingAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Valor de abertura'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: cashState.isLoading ? null : _openCashSession,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Abrir caixa'),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: 'Caixa aberto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Aberto em ${CurrencyUtils.formatDateTime(cashSummary.session.openedAt)}',
          ),
          Text(
            'Abertura: ${CurrencyUtils.formatMoney(cashSummary.session.openingAmountInCents)}',
          ),
          Text('Vendas: ${cashSummary.totalSalesCount}'),
          Text(
            'Dinheiro: ${CurrencyUtils.formatMoney(cashSummary.cashSalesInCents)}',
          ),
          Text(
            'Pix: ${CurrencyUtils.formatMoney(cashSummary.pixSalesInCents)}',
          ),
          Text(
            'Nota: ${CurrencyUtils.formatMoney(cashSummary.noteSalesInCents)}',
          ),
          Text(
            'Baixas em dinheiro: ${CurrencyUtils.formatMoney(cashSummary.receivableSettlementCashInCents)}',
          ),
          Text(
            'Baixas em Pix: ${CurrencyUtils.formatMoney(cashSummary.receivableSettlementPixInCents)}',
          ),
          Text(
            'Saldo esperado em caixa: ${CurrencyUtils.formatMoney(cashSummary.expectedCashBalanceInCents)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Movimento manual',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<CashMovementType>(
            segments: const <ButtonSegment<CashMovementType>>[
              ButtonSegment<CashMovementType>(
                value: CashMovementType.supply,
                label: Text('Suprimento'),
              ),
              ButtonSegment<CashMovementType>(
                value: CashMovementType.withdrawal,
                label: Text('Sangria'),
              ),
            ],
            selected: <CashMovementType>{_selectedMovementType},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedMovementType = selection.first;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _movementAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor do movimento'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _movementNotesController,
            decoration: const InputDecoration(labelText: 'Observacao'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: cashState.isLoading ? null : _registerCashMovement,
                child: const Text('Salvar movimento'),
              ),
              OutlinedButton(
                onPressed: cashState.isLoading ? null : _closeCashSession,
                child: const Text('Fechar caixa'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocalIndicatorsSection(
    BuildContext context,
    AsyncValue<LocalDashboardSnapshot> dashboardState,
  ) {
    return dashboardState.when(
      loading: () => const _SectionCard(
        title: 'Indicadores locais',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _SectionCard(
        title: 'Indicadores locais',
        child: Text(error.toString()),
      ),
      data: (snapshot) {
        final summary = snapshot.summary;
        return _SectionCard(
          title: 'Indicadores locais',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _MetricChip(
                label: 'Total vendido',
                value: CurrencyUtils.formatMoney(summary.totalSoldInCents),
              ),
              _MetricChip(
                label: 'Itens vendidos',
                value: '${summary.totalItemsSold}',
              ),
              _MetricChip(label: 'Vendas', value: '${summary.totalSales}'),
              _MetricChip(
                label: 'Dinheiro',
                value: CurrencyUtils.formatMoney(summary.cashSalesInCents),
              ),
              _MetricChip(
                label: 'Pix',
                value: CurrencyUtils.formatMoney(summary.pixSalesInCents),
              ),
              _MetricChip(
                label: 'Nota',
                value: CurrencyUtils.formatMoney(summary.noteSalesInCents),
              ),
              _MetricChip(
                label: 'Em aberto',
                value: CurrencyUtils.formatMoney(
                  summary.outstandingNoteAmountInCents,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSalesSection(
    BuildContext context,
    AsyncValue<LocalDashboardSnapshot> dashboardState,
  ) {
    return dashboardState.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (snapshot) {
        if (snapshot.recentSales.isEmpty) {
          return const _SectionCard(
            title: 'Vendas da sessao',
            child: Text('Nenhuma venda registrada nesta sessao ainda.'),
          );
        }

        return _SectionCard(
          title: 'Vendas da sessao',
          child: Column(
            children: snapshot.recentSales.map((sale) {
              final noteStatus = sale.paymentStatus == null
                  ? ''
                  : ' - ${sale.paymentStatus!.wireValue}';

              return Padding(
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
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          sale.saleLocalId,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(CurrencyUtils.formatDateTime(sale.createdAt)),
                        Text(
                          '${sale.itemCount} item(ns) - ${CurrencyUtils.formatMoney(sale.totalInCents)}',
                        ),
                        Text(
                          'Pagamento: ${_paymentMethodLabel(sale.paymentMethod)}$noteStatus',
                        ),
                        if (sale.customerName != null)
                          Text('Cliente: ${sale.customerName}'),
                        if ((sale.outstandingAmountInCents ?? 0) > 0)
                          Text(
                            'Em aberto: ${CurrencyUtils.formatMoney(sale.outstandingAmountInCents!)}',
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  _shareReceiptPdf(sale.receiptPath),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('PDF'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _shareSaleSummary(sale),
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Resumo'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _shareSaleOnWhatsApp(sale),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('WhatsApp'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _openCashSession() async {
    try {
      final openingAmount = CurrencyUtils.parseCurrencyToCents(
        _openingAmountController.text,
      );
      await ref
          .read(cashRegisterNotifierProvider.notifier)
          .openSession(openingAmount);
      _showMessage('Caixa aberto com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _registerCashMovement() async {
    try {
      final amount = CurrencyUtils.parseCurrencyToCents(
        _movementAmountController.text,
      );
      await ref
          .read(cashRegisterNotifierProvider.notifier)
          .registerMovement(
            type: _selectedMovementType,
            amountInCents: amount,
            notes: _movementNotesController.text.trim().isEmpty
                ? null
                : _movementNotesController.text.trim(),
          );
      _movementAmountController.clear();
      _movementNotesController.clear();
      _showMessage('Movimento de caixa salvo.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _closeCashSession() async {
    try {
      await ref.read(cashRegisterNotifierProvider.notifier).closeSession();
      _showMessage('Caixa fechado com sucesso.');
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _submitCheckout() async {
    try {
      final cart = ref.read(cartNotifierProvider);
      final amountReceived = _selectedPaymentMethod == PaymentMethod.cash
          ? CurrencyUtils.parseCurrencyToCents(_amountReceivedController.text)
          : cart.totalInCents;

      final request = CheckoutRequest(
        cart: cart,
        paymentMethod: _selectedPaymentMethod,
        amountReceivedInCents: amountReceived,
        pixConfirmedManually: _pixConfirmedManually,
        noteDueDate: _selectedDueDate,
        noteDescription: _noteDescriptionController.text.trim().isEmpty
            ? null
            : _noteDescriptionController.text.trim(),
        customerName: _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim().isEmpty
            ? null
            : _customerPhoneController.text.trim(),
      );

      await ref
          .read(checkoutNotifierProvider.notifier)
          .completeCheckout(request);
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  void _applyDiscount() {
    try {
      final rawValue = _discountController.text.trim();
      if (rawValue.isEmpty) {
        ref.read(cartNotifierProvider.notifier).applyDiscount(null);
        return;
      }

      final discount = switch (_selectedDiscountType) {
        DiscountType.value => AppliedDiscount.value(
          CurrencyUtils.parseCurrencyToCents(rawValue),
        ),
        DiscountType.percentage => AppliedDiscount.percentage(
          double.parse(rawValue.replaceAll(',', '.')),
        ),
      };

      ref.read(cartNotifierProvider.notifier).applyDiscount(discount);
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDueDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _fillQuickCustomer(QuickCustomer customer) {
    setState(() {
      _customerNameController.text = customer.name;
      _customerPhoneController.text = customer.phone;
    });
  }

  Future<void> _copyPixPayload(String payload) async {
    await Clipboard.setData(ClipboardData(text: payload));
    _showMessage('Codigo Pix copiado.');
  }

  Future<void> _shareReceiptPdf(String filePath) async {
    try {
      await ref.read(receiptShareServiceProvider).shareReceiptPdf(filePath);
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _shareSaleSummary(RecentLocalSale sale) async {
    try {
      await ref.read(receiptShareServiceProvider).shareSummaryText(sale);
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _shareSaleOnWhatsApp(RecentLocalSale sale) async {
    try {
      await ref.read(receiptShareServiceProvider).shareOnWhatsApp(sale);
    } on Object catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  int _parseCurrencyOrZero(String rawValue) {
    if (rawValue.trim().isEmpty) {
      return 0;
    }

    try {
      return CurrencyUtils.parseCurrencyToCents(rawValue);
    } on Object {
      return 0;
    }
  }

  String _paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'Dinheiro',
      PaymentMethod.pix => 'Pix manual',
      PaymentMethod.note => 'Nota',
    };
  }

  void _resetCheckoutFormAfterSuccess() {
    _discountController.clear();
    _customerNameController.clear();
    _customerPhoneController.clear();
    _amountReceivedController.clear();
    _noteDescriptionController.clear();

    setState(() {
      _selectedDiscountType = DiscountType.value;
      _selectedPaymentMethod = PaymentMethod.cash;
      _selectedDueDate = null;
      _pixConfirmedManually = false;
    });
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
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(title: title, child: child);
  }
}

AppTone _pdvMetricTone(String label) {
  switch (label) {
    case 'Dinheiro':
      return AppTone.cash;
    case 'Pix':
      return AppTone.pix;
    case 'Nota':
    case 'Em aberto':
      return AppTone.note;
    case 'Total vendido':
      return AppTone.success;
    default:
      return AppTone.info;
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppMetricTile(
      label: label,
      value: value,
      tone: _pdvMetricTone(label),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.variant, required this.onAdd});

  final ProductVariantSaleSnapshot variant;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tatuzinTokens;
    final effectivePriceInCents = variant.effectivePriceInCents;
    final priceInCents = variant.priceInCents;
    final hasPromotion = effectivePriceInCents != priceInCents;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(TatuzinSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (hasPromotion)
              const Padding(
                padding: EdgeInsets.only(bottom: TatuzinSpacing.xs),
                child: AppStatusBadge(
                  label: 'Preco promocional',
                  tone: AppTone.warning,
                ),
              ),
            Text(
              variant.displayName,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(variant.categoryName ?? 'Sem categoria'),
            if (variant.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(variant.subtitle),
              ),
            if (variant.barcode != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Codigo: ${variant.barcode}'),
              ),
            const Spacer(),
            if (hasPromotion)
              Text(
                CurrencyUtils.formatMoney(priceInCents),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            Text(
              CurrencyUtils.formatMoney(effectivePriceInCents),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: tokens.tone(AppTone.cash).foreground,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
