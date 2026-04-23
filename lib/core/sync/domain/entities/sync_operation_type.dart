enum SyncOperationType {
  sale('sale'),
  cashMovement('cash_movement'),
  quickCustomer('quick_customer'),
  receivableNote('receivable_note'),
  receivableSettlement('receivable_settlement');

  const SyncOperationType(this.wireValue);

  final String wireValue;

  static SyncOperationType fromWireValue(String value) {
    return SyncOperationType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => SyncOperationType.sale,
    );
  }
}
