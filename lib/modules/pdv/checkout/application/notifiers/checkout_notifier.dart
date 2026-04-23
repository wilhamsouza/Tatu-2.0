import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../../../../core/database/providers/database_providers.dart';
import '../../../cash_register/application/notifiers/cash_register_notifier.dart';
import '../../../quick_customer/presentation/providers/quick_customer_providers.dart';
import '../../../receipts/data/datasources/local/receipt_local_datasource.dart';
import '../../application/dtos/checkout_request.dart';
import '../../application/dtos/checkout_result.dart';
import '../../application/usecases/complete_checkout_usecase.dart';
import '../../data/datasources/local/checkout_local_datasource.dart';
import '../../data/repositories/local_checkout_repository.dart';
import '../../domain/repositories/checkout_repository.dart';

final receiptLocalDatasourceProvider = Provider<ReceiptLocalDatasource>((ref) {
  return ReceiptLocalDatasource();
});

final checkoutLocalDatasourceProvider = Provider<CheckoutLocalDatasource>((
  ref,
) {
  return CheckoutLocalDatasource(
    database: ref.read(appDatabaseProvider),
    quickCustomerLocalDatasource: ref.read(
      quickCustomerLocalDatasourceProvider,
    ),
    cashRegisterLocalDatasource: ref.read(cashRegisterLocalDatasourceProvider),
    receiptLocalDatasource: ref.read(receiptLocalDatasourceProvider),
  );
});

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return LocalCheckoutRepository(
    localDatasource: ref.read(checkoutLocalDatasourceProvider),
  );
});

final completeCheckoutUseCaseProvider = Provider<CompleteCheckoutUseCase>((
  ref,
) {
  return CompleteCheckoutUseCase(ref.read(checkoutRepositoryProvider));
});

final checkoutNotifierProvider =
    AsyncNotifierProvider<CheckoutNotifier, CheckoutResult?>(
      CheckoutNotifier.new,
    );

class CheckoutNotifier extends AsyncNotifier<CheckoutResult?> {
  @override
  Future<CheckoutResult?> build() async {
    return null;
  }

  Future<void> completeCheckout(CheckoutRequest request) async {
    final session = ref.read(sessionNotifierProvider).asData?.value;
    if (session == null) {
      throw const CheckoutException('Sessao invalida para concluir venda.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(completeCheckoutUseCaseProvider)
          .call(request: request, session: session),
    );
  }

  void clearResult() {
    state = const AsyncData(null);
  }
}
