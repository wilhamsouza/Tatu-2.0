import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../../../../../../core/utils/currency_utils.dart';
import '../../../domain/entities/receipt.dart';

class ReceiptLocalDatasource {
  ReceiptLocalDatasource({
    Uuid? uuid,
    Future<Directory> Function()? directoryResolver,
    Future<ByteData> Function(String assetKey)? assetLoader,
  }) : _uuid = uuid ?? const Uuid(),
       _directoryResolver = directoryResolver ?? _defaultDirectoryResolver,
       _assetLoader = assetLoader ?? rootBundle.load;

  final Uuid _uuid;
  final Future<Directory> Function() _directoryResolver;
  final Future<ByteData> Function(String assetKey) _assetLoader;
  Future<_ReceiptFonts>? _cachedFonts;

  Future<Receipt> generateSaleReceipt({
    required String saleLocalId,
    required String companyName,
    required String operatorName,
    String? customerName,
    String? customerPhone,
    required List<ReceiptLineItem> items,
    required String paymentMethodLabel,
    DateTime? dueDate,
    required int subtotalInCents,
    required int discountInCents,
    required int totalInCents,
    required int changeInCents,
    required DateTime createdAt,
  }) async {
    final directory = await _directoryResolver();
    final receiptDirectory = Directory(p.join(directory.path, 'receipts'));
    if (!await receiptDirectory.exists()) {
      await receiptDirectory.create(recursive: true);
    }

    final receipt = Receipt(
      localId: _uuid.v4(),
      saleLocalId: saleLocalId,
      pdfPath: p.join(receiptDirectory.path, 'comprovante-$saleLocalId.pdf'),
      createdAt: createdAt.toUtc(),
    );

    final fonts = await _loadFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    );
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                companyName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Comprovante de venda'),
              pw.Text('Venda: $saleLocalId'),
              pw.Text('Data: ${CurrencyUtils.formatDateTime(createdAt)}'),
              pw.Text('Operador: $operatorName'),
              if (customerName != null && customerName.trim().isNotEmpty)
                pw.Text('Cliente: $customerName'),
              if (customerPhone != null && customerPhone.trim().isNotEmpty)
                pw.Text('Telefone: $customerPhone'),
              pw.SizedBox(height: 12),
              pw.Text(
                'Itens',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: <pw.Widget>[
                      pw.Expanded(
                        child: pw.Text('${item.quantity}x ${item.description}'),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(CurrencyUtils.formatMoney(item.totalInCents)),
                    ],
                  ),
                ),
              ),
              pw.Divider(),
              pw.Text(
                'Subtotal: ${CurrencyUtils.formatMoney(subtotalInCents)}',
              ),
              pw.Text(
                'Desconto: ${CurrencyUtils.formatMoney(discountInCents)}',
              ),
              pw.Text(
                'Total: ${CurrencyUtils.formatMoney(totalInCents)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Pagamento: $paymentMethodLabel'),
              if (dueDate != null)
                pw.Text('Vencimento: ${CurrencyUtils.formatDate(dueDate)}'),
              if (changeInCents > 0)
                pw.Text('Troco: ${CurrencyUtils.formatMoney(changeInCents)}'),
            ],
          );
        },
      ),
    );

    final file = File(receipt.pdfPath);
    await file.writeAsBytes(await document.save());
    return receipt;
  }

  static Future<Directory> _defaultDirectoryResolver() async {
    return getApplicationDocumentsDirectory();
  }

  Future<_ReceiptFonts> _loadFonts() {
    return _cachedFonts ??= _buildFonts();
  }

  Future<_ReceiptFonts> _buildFonts() async {
    final regularFontData = await _assetLoader(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldFontData = await _assetLoader('assets/fonts/NotoSans-Bold.ttf');

    return _ReceiptFonts(
      regular: pw.Font.ttf(regularFontData),
      bold: pw.Font.ttf(boldFontData),
    );
  }
}

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.description,
    required this.quantity,
    required this.totalInCents,
  });

  final String description;
  final int quantity;
  final int totalInCents;
}

class _ReceiptFonts {
  const _ReceiptFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;
}
