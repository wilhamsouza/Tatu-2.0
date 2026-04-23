class ErpCategory {
  const ErpCategory({
    required this.id,
    required this.name,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ErpCategory.fromJson(Map<String, dynamic> json) {
    return ErpCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ErpProduct {
  const ErpProduct({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ErpProduct.fromJson(Map<String, dynamic> json) {
    return ErpProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ErpVariant {
  const ErpVariant({
    required this.id,
    required this.productId,
    required this.productName,
    this.categoryName,
    required this.displayName,
    required this.shortName,
    this.barcode,
    this.sku,
    this.color,
    this.size,
    required this.priceInCents,
    this.promotionalPriceInCents,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String? categoryName;
  final String displayName;
  final String shortName;
  final String? barcode;
  final String? sku;
  final String? color;
  final String? size;
  final int priceInCents;
  final int? promotionalPriceInCents;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ErpVariant.fromJson(Map<String, dynamic> json) {
    return ErpVariant(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      categoryName: json['categoryName'] as String?,
      displayName: json['displayName'] as String,
      shortName: json['shortName'] as String,
      barcode: json['barcode'] as String?,
      sku: json['sku'] as String?,
      color: json['color'] as String?,
      size: json['size'] as String?,
      priceInCents: json['priceInCents'] as int,
      promotionalPriceInCents: json['promotionalPriceInCents'] as int?,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ErpInventoryItem {
  const ErpInventoryItem({
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.variantDisplayName,
    required this.quantityOnHand,
    this.sku,
    this.barcode,
    this.color,
    this.size,
    required this.updatedAt,
  });

  final String variantId;
  final String productId;
  final String productName;
  final String variantDisplayName;
  final int quantityOnHand;
  final String? sku;
  final String? barcode;
  final String? color;
  final String? size;
  final DateTime updatedAt;

  factory ErpInventoryItem.fromJson(Map<String, dynamic> json) {
    return ErpInventoryItem(
      variantId: json['variantId'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      variantDisplayName: json['variantDisplayName'] as String,
      quantityOnHand: json['quantityOnHand'] as int,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      color: json['color'] as String?,
      size: json['size'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ErpSupplier {
  const ErpSupplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ErpSupplier.fromJson(Map<String, dynamic> json) {
    return ErpSupplier(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ErpPurchaseItem {
  const ErpPurchaseItem({
    required this.id,
    required this.variantId,
    required this.variantDisplayName,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCostInCents,
    required this.lineTotalInCents,
  });

  final String id;
  final String variantId;
  final String variantDisplayName;
  final int quantityOrdered;
  final int quantityReceived;
  final int unitCostInCents;
  final int lineTotalInCents;

  int get pendingQuantity => quantityOrdered - quantityReceived;

  factory ErpPurchaseItem.fromJson(Map<String, dynamic> json) {
    return ErpPurchaseItem(
      id: json['id'] as String,
      variantId: json['variantId'] as String,
      variantDisplayName: json['variantDisplayName'] as String,
      quantityOrdered: json['quantityOrdered'] as int,
      quantityReceived: json['quantityReceived'] as int,
      unitCostInCents: json['unitCostInCents'] as int,
      lineTotalInCents: json['lineTotalInCents'] as int,
    );
  }
}

class ErpPurchaseReceiptLine {
  const ErpPurchaseReceiptLine({
    required this.purchaseItemId,
    required this.variantId,
    required this.quantityReceived,
  });

  final String purchaseItemId;
  final String variantId;
  final int quantityReceived;

  factory ErpPurchaseReceiptLine.fromJson(Map<String, dynamic> json) {
    return ErpPurchaseReceiptLine(
      purchaseItemId: json['purchaseItemId'] as String,
      variantId: json['variantId'] as String,
      quantityReceived: json['quantityReceived'] as int,
    );
  }
}

class ErpPurchaseReceipt {
  const ErpPurchaseReceipt({
    required this.id,
    required this.purchaseOrderId,
    required this.receivedAt,
    required this.createdAt,
    required this.lines,
  });

  final String id;
  final String purchaseOrderId;
  final DateTime receivedAt;
  final DateTime createdAt;
  final List<ErpPurchaseReceiptLine> lines;

  factory ErpPurchaseReceipt.fromJson(Map<String, dynamic> json) {
    return ErpPurchaseReceipt(
      id: json['id'] as String,
      purchaseOrderId: json['purchaseOrderId'] as String,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lines: _readItems(
        json['lines'],
      ).map(ErpPurchaseReceiptLine.fromJson).toList(),
    );
  }
}

class ErpPurchase {
  const ErpPurchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.receipts,
  });

  final String id;
  final String supplierId;
  final String supplierName;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ErpPurchaseItem> items;
  final List<ErpPurchaseReceipt> receipts;

  bool get canReceive => status == 'pending' || status == 'partially_received';

  factory ErpPurchase.fromJson(Map<String, dynamic> json) {
    return ErpPurchase(
      id: json['id'] as String,
      supplierId: json['supplierId'] as String,
      supplierName: json['supplierName'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      items: _readItems(json['items']).map(ErpPurchaseItem.fromJson).toList(),
      receipts: _readItems(
        json['receipts'],
      ).map(ErpPurchaseReceipt.fromJson).toList(),
    );
  }
}

class ErpReceivableNote {
  const ErpReceivableNote({
    required this.id,
    required this.saleId,
    this.customerId,
    required this.originalAmountInCents,
    required this.paidAmountInCents,
    required this.outstandingAmountInCents,
    required this.dueDate,
    required this.issueDate,
    required this.status,
    this.notes,
  });

  final String id;
  final String saleId;
  final String? customerId;
  final int originalAmountInCents;
  final int paidAmountInCents;
  final int outstandingAmountInCents;
  final DateTime dueDate;
  final DateTime issueDate;
  final String status;
  final String? notes;

  bool get canSettle =>
      status == 'pending' || status == 'partially_paid' || status == 'overdue';

  factory ErpReceivableNote.fromJson(Map<String, dynamic> json) {
    return ErpReceivableNote(
      id: json['id'] as String,
      saleId: json['saleId'] as String,
      customerId: json['customerId'] as String?,
      originalAmountInCents: json['originalAmountInCents'] as int,
      paidAmountInCents: json['paidAmountInCents'] as int? ?? 0,
      outstandingAmountInCents:
          json['outstandingAmountInCents'] as int? ??
          json['originalAmountInCents'] as int,
      dueDate: DateTime.parse(json['dueDate'] as String),
      issueDate: DateTime.parse(json['issueDate'] as String),
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }
}

class ErpCashSession {
  const ErpCashSession({
    required this.cashSessionLocalId,
    required this.status,
    this.openedAt,
    this.closedAt,
    this.updatedAt,
    required this.openingAmountInCents,
    required this.cashSalesInCents,
    required this.pixSalesInCents,
    required this.noteSalesInCents,
    required this.suppliesInCents,
    required this.withdrawalsInCents,
    required this.receivableSettlementCashInCents,
    required this.receivableSettlementPixInCents,
    required this.expectedCashBalanceInCents,
    required this.movementCount,
  });

  final String cashSessionLocalId;
  final String status;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final DateTime? updatedAt;
  final int openingAmountInCents;
  final int cashSalesInCents;
  final int pixSalesInCents;
  final int noteSalesInCents;
  final int suppliesInCents;
  final int withdrawalsInCents;
  final int receivableSettlementCashInCents;
  final int receivableSettlementPixInCents;
  final int expectedCashBalanceInCents;
  final int movementCount;

  factory ErpCashSession.fromJson(Map<String, dynamic> json) {
    return ErpCashSession(
      cashSessionLocalId: json['cashSessionLocalId'] as String,
      status: json['status'] as String? ?? 'open',
      openedAt: _parseOptionalDate(json['openedAt']),
      closedAt: _parseOptionalDate(json['closedAt']),
      updatedAt: _parseOptionalDate(json['updatedAt']),
      openingAmountInCents: json['openingAmountInCents'] as int? ?? 0,
      cashSalesInCents: json['cashSalesInCents'] as int? ?? 0,
      pixSalesInCents: json['pixSalesInCents'] as int? ?? 0,
      noteSalesInCents: json['noteSalesInCents'] as int? ?? 0,
      suppliesInCents: json['suppliesInCents'] as int? ?? 0,
      withdrawalsInCents: json['withdrawalsInCents'] as int? ?? 0,
      receivableSettlementCashInCents:
          json['receivableSettlementCashInCents'] as int? ?? 0,
      receivableSettlementPixInCents:
          json['receivableSettlementPixInCents'] as int? ?? 0,
      expectedCashBalanceInCents:
          json['expectedCashBalanceInCents'] as int? ?? 0,
      movementCount: json['movementCount'] as int? ?? 0,
    );
  }
}

enum ErpReportPeriod {
  daily('daily', 'Diario'),
  weekly('weekly', 'Semanal'),
  monthly('monthly', 'Mensal');

  const ErpReportPeriod(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ErpReportPeriod fromWireValue(String value) {
    return ErpReportPeriod.values.firstWhere(
      (period) => period.wireValue == value,
      orElse: () => ErpReportPeriod.daily,
    );
  }
}

class ErpReportPaymentBreakdown {
  const ErpReportPaymentBreakdown({
    required this.method,
    required this.amountInCents,
    required this.transactionCount,
  });

  final String method;
  final int amountInCents;
  final int transactionCount;

  factory ErpReportPaymentBreakdown.fromJson(Map<String, dynamic> json) {
    return ErpReportPaymentBreakdown(
      method: json['method'] as String,
      amountInCents: json['amountInCents'] as int? ?? 0,
      transactionCount: json['transactionCount'] as int? ?? 0,
    );
  }
}

class ErpReportRankingItem {
  const ErpReportRankingItem({
    required this.id,
    required this.label,
    required this.unitsSold,
    required this.revenueInCents,
    required this.salesCount,
  });

  final String id;
  final String label;
  final int unitsSold;
  final int revenueInCents;
  final int salesCount;

  factory ErpReportRankingItem.fromJson(Map<String, dynamic> json) {
    return ErpReportRankingItem(
      id: json['id'] as String,
      label: json['label'] as String,
      unitsSold: json['unitsSold'] as int? ?? 0,
      revenueInCents: json['revenueInCents'] as int? ?? 0,
      salesCount: json['salesCount'] as int? ?? 0,
    );
  }
}

class ErpPeriodReport {
  ErpPeriodReport({
    required this.period,
    required this.label,
    required this.startsAt,
    required this.endsAt,
    required this.salesCount,
    required this.itemsSold,
    required this.grossRevenueInCents,
    required this.discountInCents,
    required this.netRevenueInCents,
    required this.averageTicketInCents,
    required this.liquidatedRevenueInCents,
    required this.noteRevenueInCents,
    required this.openReceivablesInCents,
    required this.overdueReceivablesInCents,
    required this.openReceivablesCount,
    required this.overdueReceivablesCount,
    required this.paymentBreakdown,
    required this.topProducts,
    required this.topVariants,
  });

  final ErpReportPeriod period;
  final String label;
  final DateTime startsAt;
  final DateTime endsAt;
  final int salesCount;
  final int itemsSold;
  final int grossRevenueInCents;
  final int discountInCents;
  final int netRevenueInCents;
  final int averageTicketInCents;
  final int liquidatedRevenueInCents;
  final int noteRevenueInCents;
  final int openReceivablesInCents;
  final int overdueReceivablesInCents;
  final int openReceivablesCount;
  final int overdueReceivablesCount;
  final List<ErpReportPaymentBreakdown> paymentBreakdown;
  final List<ErpReportRankingItem> topProducts;
  final List<ErpReportRankingItem> topVariants;

  factory ErpPeriodReport.fromJson(Map<String, dynamic> json) {
    return ErpPeriodReport(
      period: ErpReportPeriod.fromWireValue(json['period'] as String),
      label: json['label'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      salesCount: json['salesCount'] as int? ?? 0,
      itemsSold: json['itemsSold'] as int? ?? 0,
      grossRevenueInCents: json['grossRevenueInCents'] as int? ?? 0,
      discountInCents: json['discountInCents'] as int? ?? 0,
      netRevenueInCents: json['netRevenueInCents'] as int? ?? 0,
      averageTicketInCents: json['averageTicketInCents'] as int? ?? 0,
      liquidatedRevenueInCents: json['liquidatedRevenueInCents'] as int? ?? 0,
      noteRevenueInCents: json['noteRevenueInCents'] as int? ?? 0,
      openReceivablesInCents: json['openReceivablesInCents'] as int? ?? 0,
      overdueReceivablesInCents: json['overdueReceivablesInCents'] as int? ?? 0,
      openReceivablesCount: json['openReceivablesCount'] as int? ?? 0,
      overdueReceivablesCount: json['overdueReceivablesCount'] as int? ?? 0,
      paymentBreakdown: _readItems(
        json['paymentBreakdown'],
      ).map(ErpReportPaymentBreakdown.fromJson).toList(),
      topProducts: _readItems(
        json['topProducts'],
      ).map(ErpReportRankingItem.fromJson).toList(),
      topVariants: _readItems(
        json['topVariants'],
      ).map(ErpReportRankingItem.fromJson).toList(),
    );
  }

  factory ErpPeriodReport.empty(ErpReportPeriod period) {
    final zero = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return ErpPeriodReport(
      period: period,
      label: period.label,
      startsAt: zero,
      endsAt: zero,
      salesCount: 0,
      itemsSold: 0,
      grossRevenueInCents: 0,
      discountInCents: 0,
      netRevenueInCents: 0,
      averageTicketInCents: 0,
      liquidatedRevenueInCents: 0,
      noteRevenueInCents: 0,
      openReceivablesInCents: 0,
      overdueReceivablesInCents: 0,
      openReceivablesCount: 0,
      overdueReceivablesCount: 0,
      paymentBreakdown: const <ErpReportPaymentBreakdown>[],
      topProducts: const <ErpReportRankingItem>[],
      topVariants: const <ErpReportRankingItem>[],
    );
  }
}

class ErpReportsDashboard {
  ErpReportsDashboard({
    required this.generatedAt,
    required this.referenceDate,
    required this.daily,
    required this.weekly,
    required this.monthly,
  });

  final DateTime generatedAt;
  final DateTime referenceDate;
  final ErpPeriodReport daily;
  final ErpPeriodReport weekly;
  final ErpPeriodReport monthly;

  factory ErpReportsDashboard.fromJson(Map<String, dynamic> json) {
    final reports = (json['reports'] as Map).cast<String, dynamic>();
    return ErpReportsDashboard(
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      referenceDate: DateTime.parse(json['referenceDate'] as String),
      daily: ErpPeriodReport.fromJson(
        (reports['daily'] as Map).cast<String, dynamic>(),
      ),
      weekly: ErpPeriodReport.fromJson(
        (reports['weekly'] as Map).cast<String, dynamic>(),
      ),
      monthly: ErpPeriodReport.fromJson(
        (reports['monthly'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  factory ErpReportsDashboard.empty() {
    final zero = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return ErpReportsDashboard(
      generatedAt: zero,
      referenceDate: zero,
      daily: ErpPeriodReport.empty(ErpReportPeriod.daily),
      weekly: ErpPeriodReport.empty(ErpReportPeriod.weekly),
      monthly: ErpPeriodReport.empty(ErpReportPeriod.monthly),
    );
  }

  ErpPeriodReport reportFor(ErpReportPeriod period) {
    switch (period) {
      case ErpReportPeriod.daily:
        return daily;
      case ErpReportPeriod.weekly:
        return weekly;
      case ErpReportPeriod.monthly:
        return monthly;
    }
  }
}

class ErpOverview {
  const ErpOverview({
    required this.categories,
    required this.products,
    required this.variants,
    required this.inventoryItems,
    required this.suppliers,
    required this.purchases,
    required this.receivables,
    required this.cashSessions,
  });

  final List<ErpCategory> categories;
  final List<ErpProduct> products;
  final List<ErpVariant> variants;
  final List<ErpInventoryItem> inventoryItems;
  final List<ErpSupplier> suppliers;
  final List<ErpPurchase> purchases;
  final List<ErpReceivableNote> receivables;
  final List<ErpCashSession> cashSessions;

  const ErpOverview.empty()
    : categories = const <ErpCategory>[],
      products = const <ErpProduct>[],
      variants = const <ErpVariant>[],
      inventoryItems = const <ErpInventoryItem>[],
      suppliers = const <ErpSupplier>[],
      purchases = const <ErpPurchase>[],
      receivables = const <ErpReceivableNote>[],
      cashSessions = const <ErpCashSession>[];

  int get totalInventoryUnits =>
      inventoryItems.fold(0, (sum, item) => sum + item.quantityOnHand);

  int get openPurchaseCount =>
      purchases.where((purchase) => purchase.canReceive).length;

  int get outstandingReceivablesInCents =>
      receivables.fold(0, (sum, note) => sum + note.outstandingAmountInCents);

  int get openCashSessionCount =>
      cashSessions.where((session) => session.status == 'open').length;
}

List<Map<String, dynamic>> _readItems(dynamic value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => (item as Map).cast<String, dynamic>())
      .toList();
}

DateTime? _parseOptionalDate(dynamic value) {
  return value is String && value.isNotEmpty ? DateTime.parse(value) : null;
}
