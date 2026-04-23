class CrmCustomer {
  const CrmCustomer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.source,
    required this.totalPurchases,
    required this.totalSpentInCents,
    this.lastPurchaseAt,
    required this.totalOutstandingInCents,
    required this.openReceivablesCount,
    required this.overdueReceivablesCount,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String source;
  final int totalPurchases;
  final int totalSpentInCents;
  final DateTime? lastPurchaseAt;
  final int totalOutstandingInCents;
  final int openReceivablesCount;
  final int overdueReceivablesCount;

  factory CrmCustomer.fromJson(Map<String, dynamic> json) {
    return CrmCustomer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      source: json['source'] as String? ?? 'manual',
      totalPurchases: json['totalPurchases'] as int? ?? 0,
      totalSpentInCents: json['totalSpentInCents'] as int? ?? 0,
      lastPurchaseAt: json['lastPurchaseAt'] == null
          ? null
          : DateTime.parse(json['lastPurchaseAt'] as String),
      totalOutstandingInCents: json['totalOutstandingInCents'] as int? ?? 0,
      openReceivablesCount: json['openReceivablesCount'] as int? ?? 0,
      overdueReceivablesCount: json['overdueReceivablesCount'] as int? ?? 0,
    );
  }
}

class CrmReceivableNote {
  const CrmReceivableNote({
    required this.noteId,
    required this.saleId,
    required this.originalAmountInCents,
    required this.paidAmountInCents,
    required this.outstandingAmountInCents,
    required this.dueDate,
    required this.issueDate,
    required this.status,
  });

  final String noteId;
  final String saleId;
  final int originalAmountInCents;
  final int paidAmountInCents;
  final int outstandingAmountInCents;
  final DateTime dueDate;
  final DateTime issueDate;
  final String status;

  factory CrmReceivableNote.fromJson(Map<String, dynamic> json) {
    return CrmReceivableNote(
      noteId: json['noteId'] as String,
      saleId: json['saleId'] as String,
      originalAmountInCents: json['originalAmountInCents'] as int,
      paidAmountInCents: json['paidAmountInCents'] as int,
      outstandingAmountInCents: json['outstandingAmountInCents'] as int,
      dueDate: DateTime.parse(json['dueDate'] as String),
      issueDate: DateTime.parse(json['issueDate'] as String),
      status: json['status'] as String,
    );
  }
}

class CrmSaleItem {
  const CrmSaleItem({
    this.variantId,
    required this.displayName,
    required this.quantity,
    required this.unitPriceInCents,
    required this.totalPriceInCents,
  });

  final String? variantId;
  final String displayName;
  final int quantity;
  final int unitPriceInCents;
  final int totalPriceInCents;

  factory CrmSaleItem.fromJson(Map<String, dynamic> json) {
    return CrmSaleItem(
      variantId: json['variantId'] as String?,
      displayName: json['displayName'] as String,
      quantity: json['quantity'] as int,
      unitPriceInCents: json['unitPriceInCents'] as int,
      totalPriceInCents: json['totalPriceInCents'] as int,
    );
  }
}

class CrmPurchaseHistoryItem {
  const CrmPurchaseHistoryItem({
    required this.saleId,
    required this.createdAt,
    required this.subtotalInCents,
    required this.discountInCents,
    required this.totalInCents,
    required this.itemCount,
    required this.paymentMethods,
    required this.items,
    required this.outstandingAmountInCents,
    this.receivableStatus,
    this.receivableDueDate,
  });

  final String saleId;
  final DateTime createdAt;
  final int subtotalInCents;
  final int discountInCents;
  final int totalInCents;
  final int itemCount;
  final List<String> paymentMethods;
  final List<CrmSaleItem> items;
  final int outstandingAmountInCents;
  final String? receivableStatus;
  final DateTime? receivableDueDate;

  factory CrmPurchaseHistoryItem.fromJson(Map<String, dynamic> json) {
    return CrmPurchaseHistoryItem(
      saleId: json['saleId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      subtotalInCents: json['subtotalInCents'] as int,
      discountInCents: json['discountInCents'] as int,
      totalInCents: json['totalInCents'] as int,
      itemCount: json['itemCount'] as int,
      paymentMethods:
          (json['paymentMethods'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      items: _readItems(json['items']).map(CrmSaleItem.fromJson).toList(),
      outstandingAmountInCents: json['outstandingAmountInCents'] as int? ?? 0,
      receivableStatus: json['receivableStatus'] as String?,
      receivableDueDate: json['receivableDueDate'] == null
          ? null
          : DateTime.parse(json['receivableDueDate'] as String),
    );
  }
}

class CrmCustomerHistory {
  const CrmCustomerHistory({required this.customer, required this.purchases});

  final CrmCustomer customer;
  final List<CrmPurchaseHistoryItem> purchases;

  factory CrmCustomerHistory.fromJson(Map<String, dynamic> json) {
    return CrmCustomerHistory(
      customer: CrmCustomer.fromJson(
        (json['customer'] as Map).cast<String, dynamic>(),
      ),
      purchases: _readItems(
        json['purchases'],
      ).map(CrmPurchaseHistoryItem.fromJson).toList(),
    );
  }
}

class CrmCustomerSummary {
  const CrmCustomerSummary({
    required this.customer,
    required this.totalPurchases,
    required this.totalSpentInCents,
    required this.averageTicketInCents,
    this.lastPurchaseAt,
    required this.totalOutstandingInCents,
    required this.openReceivablesCount,
    required this.overdueReceivablesCount,
    required this.receivables,
  });

  final CrmCustomer customer;
  final int totalPurchases;
  final int totalSpentInCents;
  final int averageTicketInCents;
  final DateTime? lastPurchaseAt;
  final int totalOutstandingInCents;
  final int openReceivablesCount;
  final int overdueReceivablesCount;
  final List<CrmReceivableNote> receivables;

  factory CrmCustomerSummary.fromJson(Map<String, dynamic> json) {
    return CrmCustomerSummary(
      customer: CrmCustomer.fromJson(
        (json['customer'] as Map).cast<String, dynamic>(),
      ),
      totalPurchases: json['totalPurchases'] as int? ?? 0,
      totalSpentInCents: json['totalSpentInCents'] as int? ?? 0,
      averageTicketInCents: json['averageTicketInCents'] as int? ?? 0,
      lastPurchaseAt: json['lastPurchaseAt'] == null
          ? null
          : DateTime.parse(json['lastPurchaseAt'] as String),
      totalOutstandingInCents: json['totalOutstandingInCents'] as int? ?? 0,
      openReceivablesCount: json['openReceivablesCount'] as int? ?? 0,
      overdueReceivablesCount: json['overdueReceivablesCount'] as int? ?? 0,
      receivables: _readItems(
        json['receivables'],
      ).map(CrmReceivableNote.fromJson).toList(),
    );
  }
}

class CrmDirectoryState {
  const CrmDirectoryState({
    required this.query,
    required this.customers,
    this.selectedCustomerId,
    this.selectedSummary,
    this.selectedHistory,
  });

  const CrmDirectoryState.empty()
    : query = '',
      customers = const <CrmCustomer>[],
      selectedCustomerId = null,
      selectedSummary = null,
      selectedHistory = null;

  final String query;
  final List<CrmCustomer> customers;
  final String? selectedCustomerId;
  final CrmCustomerSummary? selectedSummary;
  final CrmCustomerHistory? selectedHistory;

  CrmDirectoryState copyWith({
    String? query,
    List<CrmCustomer>? customers,
    String? selectedCustomerId,
    bool clearSelectedCustomerId = false,
    CrmCustomerSummary? selectedSummary,
    bool clearSelectedSummary = false,
    CrmCustomerHistory? selectedHistory,
    bool clearSelectedHistory = false,
  }) {
    return CrmDirectoryState(
      query: query ?? this.query,
      customers: customers ?? this.customers,
      selectedCustomerId: clearSelectedCustomerId
          ? null
          : selectedCustomerId ?? this.selectedCustomerId,
      selectedSummary: clearSelectedSummary
          ? null
          : selectedSummary ?? this.selectedSummary,
      selectedHistory: clearSelectedHistory
          ? null
          : selectedHistory ?? this.selectedHistory,
    );
  }

  CrmCustomer? get selectedCustomer {
    final customerId = selectedCustomerId;
    if (customerId == null) {
      return null;
    }

    for (final customer in customers) {
      if (customer.id == customerId) {
        return customer;
      }
    }
    return null;
  }
}

List<Map<String, dynamic>> _readItems(dynamic value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => (item as Map).cast<String, dynamic>())
      .toList();
}
