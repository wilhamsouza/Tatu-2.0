class LocalSale {
  const LocalSale({
    required this.localId,
    this.remoteId,
    required this.companyId,
    required this.userId,
    this.customerLocalId,
    this.customerRemoteId,
    required this.cashSessionLocalId,
    required this.subtotalInCents,
    required this.discountInCents,
    required this.totalInCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });

  final String localId;
  final String? remoteId;
  final String companyId;
  final String userId;
  final String? customerLocalId;
  final String? customerRemoteId;
  final String cashSessionLocalId;
  final int subtotalInCents;
  final int discountInCents;
  final int totalInCents;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
}
