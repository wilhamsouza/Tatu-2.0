enum SettlementPaymentMethod {
  cash('cash'),
  pix('pix');

  const SettlementPaymentMethod(this.wireValue);

  final String wireValue;

  static SettlementPaymentMethod fromWireValue(String value) {
    return SettlementPaymentMethod.values.firstWhere(
      (method) => method.wireValue == value,
      orElse: () => SettlementPaymentMethod.cash,
    );
  }
}
