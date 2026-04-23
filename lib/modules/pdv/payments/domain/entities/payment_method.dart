enum PaymentMethod {
  cash('cash'),
  pix('pix'),
  note('note');

  const PaymentMethod(this.wireValue);

  final String wireValue;
}
