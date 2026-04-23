import '../../domain/entities/payment_method.dart';

class PixPayloadService {
  const PixPayloadService();

  String buildManualPayload({
    required int totalInCents,
    required String companyName,
    required String deviceId,
  }) {
    final normalizedCompany = companyName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
        .trim();
    final amount = (totalInCents / 100).toStringAsFixed(2);

    return 'TATUZIN|PIX|EMPRESA=$normalizedCompany|VALOR=$amount|DEVICE=$deviceId|MODO=${PaymentMethod.pix.wireValue.toUpperCase()}';
  }
}
