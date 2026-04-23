import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services/pix_payload_service.dart';

final pixPayloadServiceProvider = Provider<PixPayloadService>((ref) {
  return const PixPayloadService();
});
