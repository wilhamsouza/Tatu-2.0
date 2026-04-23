enum CashMovementType {
  opening('opening'),
  saleCash('sale_cash'),
  salePix('sale_pix'),
  saleNote('sale_note'),
  supply('supply'),
  withdrawal('withdrawal'),
  receivableSettlementCash('receivable_settlement_cash'),
  receivableSettlementPix('receivable_settlement_pix'),
  closing('closing');

  const CashMovementType(this.wireValue);

  final String wireValue;

  static CashMovementType fromWireValue(String value) {
    return CashMovementType.values.firstWhere(
      (entry) => entry.wireValue == value,
      orElse: () => CashMovementType.opening,
    );
  }
}
