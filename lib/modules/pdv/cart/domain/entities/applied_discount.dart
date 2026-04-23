import 'discount_type.dart';

class AppliedDiscount {
  const AppliedDiscount.value(this.amountInCents)
    : type = DiscountType.value,
      percentage = null;

  const AppliedDiscount.percentage(this.percentage)
    : type = DiscountType.percentage,
      amountInCents = null;

  final DiscountType type;
  final int? amountInCents;
  final double? percentage;

  int resolveAmountInCents(int subtotalInCents) {
    if (subtotalInCents <= 0) {
      return 0;
    }

    switch (type) {
      case DiscountType.value:
        final resolved = amountInCents ?? 0;
        return resolved.clamp(0, subtotalInCents);
      case DiscountType.percentage:
        final resolvedPercentage = percentage ?? 0;
        final resolved = (subtotalInCents * (resolvedPercentage / 100)).round();
        return resolved.clamp(0, subtotalInCents);
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type.name,
      'amountInCents': amountInCents,
      'percentage': percentage,
    };
  }

  factory AppliedDiscount.fromJson(Map<String, dynamic> json) {
    final type = DiscountType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => DiscountType.value,
    );
    return switch (type) {
      DiscountType.value => AppliedDiscount.value(
        (json['amountInCents'] as num?)?.round() ?? 0,
      ),
      DiscountType.percentage => AppliedDiscount.percentage(
        (json['percentage'] as num?)?.toDouble() ?? 0,
      ),
    };
  }
}
