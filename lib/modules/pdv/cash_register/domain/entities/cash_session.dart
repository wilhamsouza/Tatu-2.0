class CashSession {
  const CashSession({
    required this.localId,
    this.remoteId,
    required this.userId,
    required this.openingAmountInCents,
    required this.status,
    required this.openedAt,
    this.closedAt,
  });

  final String localId;
  final String? remoteId;
  final String userId;
  final int openingAmountInCents;
  final String status;
  final DateTime openedAt;
  final DateTime? closedAt;

  bool get isOpen => status == 'open';
}
