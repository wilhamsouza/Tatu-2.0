import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services/receipt_share_service.dart';

final receiptShareServiceProvider = Provider<ReceiptShareService>((ref) {
  return const ReceiptShareService();
});
