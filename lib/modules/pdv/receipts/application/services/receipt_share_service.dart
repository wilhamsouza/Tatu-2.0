import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/utils/currency_utils.dart';
import '../../../local_dashboard/domain/entities/recent_local_sale.dart';

class ReceiptShareService {
  const ReceiptShareService();

  Future<void> shareReceiptPdf(String filePath) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(filePath)],
        text: 'Comprovante de venda Tatuzin 2.0',
      ),
    );
  }

  Future<void> shareSummaryText(RecentLocalSale sale) async {
    await SharePlus.instance.share(
      ShareParams(text: buildSummaryMessage(sale)),
    );
  }

  Future<void> shareOnWhatsApp(RecentLocalSale sale) async {
    final message = buildSummaryMessage(sale);
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUri = Uri.parse('https://wa.me/?text=$encodedMessage');
    final launched = await launchUrl(
      whatsappUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      await shareSummaryText(sale);
    }
  }

  String buildSummaryMessage(RecentLocalSale sale) {
    final customerLine = sale.customerName == null
        ? 'Cliente rapido nao informado'
        : 'Cliente: ${sale.customerName}';

    final noteLine =
        sale.outstandingAmountInCents != null &&
            sale.outstandingAmountInCents! > 0
        ? '\nEm aberto: ${CurrencyUtils.formatMoney(sale.outstandingAmountInCents!)}'
        : '';

    return '''
Tatuzin 2.0
Venda: ${sale.saleLocalId}
Data: ${CurrencyUtils.formatDateTime(sale.createdAt)}
$customerLine
Total: ${CurrencyUtils.formatMoney(sale.totalInCents)}
Itens: ${sale.itemCount}
Pagamento: ${_paymentLabel(sale)}$noteLine
'''
        .trim();
  }

  String _paymentLabel(RecentLocalSale sale) {
    final base = switch (sale.paymentMethod) {
      var method when method.wireValue == 'cash' => 'Dinheiro',
      var method when method.wireValue == 'pix' => 'Pix manual',
      _ => 'Nota',
    };

    if (sale.paymentStatus == null) {
      return base;
    }

    return '$base (${sale.paymentStatus!.wireValue})';
  }

  Future<bool> receiptExists(String filePath) async {
    return File(filePath).exists();
  }
}
