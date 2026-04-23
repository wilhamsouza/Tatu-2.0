enum PaymentStatus {
  pending('pending'),
  partiallyPaid('partially_paid'),
  paid('paid'),
  overdue('overdue'),
  canceled('canceled');

  const PaymentStatus(this.wireValue);

  final String wireValue;
}
