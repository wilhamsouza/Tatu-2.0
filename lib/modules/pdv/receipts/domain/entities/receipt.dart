class Receipt {
  const Receipt({
    required this.localId,
    required this.saleLocalId,
    required this.pdfPath,
    this.sharedAt,
    required this.createdAt,
  });

  final String localId;
  final String saleLocalId;
  final String pdfPath;
  final DateTime? sharedAt;
  final DateTime createdAt;
}
