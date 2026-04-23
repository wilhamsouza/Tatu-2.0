import 'package:intl/intl.dart';

class CurrencyUtils {
  const CurrencyUtils._();

  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

  static String formatMoney(int amountInCents) {
    return _currencyFormatter
        .format(amountInCents / 100)
        .replaceAll('\u00A0', ' ');
  }

  static String formatDate(DateTime date) {
    return _dateFormatter.format(date.toLocal());
  }

  static String formatDateTime(DateTime date) {
    return _dateTimeFormatter.format(date.toLocal());
  }

  static int parseCurrencyToCents(String rawValue) {
    final sanitized = rawValue
        .trim()
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');

    if (sanitized.isEmpty) {
      return 0;
    }

    final parsed = double.tryParse(sanitized);
    if (parsed == null) {
      throw const CurrencyParseException(
        'Nao foi possivel interpretar o valor monetario informado.',
      );
    }

    return (parsed * 100).round();
  }

  static String normalizePhone(String rawValue) {
    return rawValue.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

class CurrencyParseException implements Exception {
  const CurrencyParseException(this.message);

  final String message;

  @override
  String toString() => message;
}
