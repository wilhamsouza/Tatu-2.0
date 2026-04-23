import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../domain/entities/erp_entities.dart';
import '../../domain/repositories/erp_repository.dart';
import '../../presentation/providers/erp_providers.dart';

final erpReportsNotifierProvider =
    AsyncNotifierProvider<ErpReportsNotifier, ErpReportsDashboard>(
      ErpReportsNotifier.new,
    );

class ErpReportsNotifier extends AsyncNotifier<ErpReportsDashboard> {
  ErpRepository get _repository => ref.read(erpRepositoryProvider);

  @override
  Future<ErpReportsDashboard> build() async {
    ref.watch(sessionNotifierProvider);
    return _loadReports();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadReports);
  }

  Future<ErpReportsDashboard> _loadReports() async {
    final accessToken = ref
        .read(sessionNotifierProvider)
        .asData
        ?.value
        ?.tokens
        .accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return ErpReportsDashboard.empty();
    }

    return _repository.loadReportsDashboard(accessToken: accessToken);
  }
}
