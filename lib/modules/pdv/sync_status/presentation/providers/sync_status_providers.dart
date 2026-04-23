import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/application/notifiers/session_notifier.dart';
import '../../../../../core/auth/application/providers/auth_providers.dart';
import '../../../../../core/connectivity/application/providers/connectivity_providers.dart';
import '../../../../../core/connectivity/domain/entities/connectivity_status.dart';
import '../../../../../core/database/providers/database_providers.dart';
import '../../../../../core/sync/application/dtos/sync_run_summary.dart';
import '../../../../../core/sync/application/services/sync_heartbeat_coordinator.dart';
import '../../../../../core/sync/application/services/sync_engine_service.dart';
import '../../../../../core/sync/data/datasources/local/sync_inbox_local_datasource.dart';
import '../../../../../core/sync/data/datasources/local/sync_outbox_local_datasource.dart';
import '../../../../../core/sync/data/datasources/remote/sync_remote_datasource.dart';
import '../../../../../core/sync/domain/entities/sync_status_snapshot.dart';
import '../../application/dtos/sync_status_details.dart';
import '../../data/datasources/local/sync_status_local_datasource.dart';

final syncOutboxLocalDatasourceProvider = Provider<SyncOutboxLocalDatasource>((
  ref,
) {
  return SyncOutboxLocalDatasource(database: ref.read(appDatabaseProvider));
});

final syncInboxLocalDatasourceProvider = Provider<SyncInboxLocalDatasource>((
  ref,
) {
  return SyncInboxLocalDatasource(database: ref.read(appDatabaseProvider));
});

final syncRemoteDatasourceProvider = Provider<SyncRemoteDatasource>((ref) {
  return SyncRemoteDatasource(apiClient: ref.read(apiClientProvider));
});

final syncEngineServiceProvider = Provider<SyncEngineService>((ref) {
  return SyncEngineService(
    outboxLocalDatasource: ref.read(syncOutboxLocalDatasourceProvider),
    inboxLocalDatasource: ref.read(syncInboxLocalDatasourceProvider),
    remoteDatasource: ref.read(syncRemoteDatasourceProvider),
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
});

final syncStatusLocalDatasourceProvider = Provider<SyncStatusLocalDatasource>((
  ref,
) {
  return SyncStatusLocalDatasource(
    database: ref.read(appDatabaseProvider),
    apiClient: ref.read(apiClientProvider),
  );
});

final syncNotifierProvider =
    AsyncNotifierProvider<SyncNotifier, SyncStatusSnapshot>(SyncNotifier.new);

class SyncNotifier extends AsyncNotifier<SyncStatusSnapshot> {
  SyncOutboxLocalDatasource get _outboxDatasource =>
      ref.read(syncOutboxLocalDatasourceProvider);
  SyncEngineService get _engine => ref.read(syncEngineServiceProvider);

  @override
  Future<SyncStatusSnapshot> build() {
    return _outboxDatasource.loadStatusSnapshot();
  }

  Future<SyncRunSummary> runNow() async {
    final session = ref.read(sessionNotifierProvider).asData?.value;
    final connectivityStatus = ref.read(currentConnectivityStatusProvider);
    final isOffline = connectivityStatus == ConnectivityStatus.offline;

    if (session == null || isOffline) {
      return const SyncRunSummary();
    }

    final summary = await _engine.runOnce(session: session);
    state = AsyncData(await _outboxDatasource.loadStatusSnapshot());
    return summary;
  }

  Future<void> refresh() async {
    state = AsyncData(await _outboxDatasource.loadStatusSnapshot());
  }
}

final syncHeartbeatProvider = Provider<SyncHeartbeatCoordinator?>((ref) {
  final session = ref.watch(sessionNotifierProvider).asData?.value;
  final connectivityStatus = ref.watch(currentConnectivityStatusProvider);
  final canRunHeartbeat =
      connectivityStatus == ConnectivityStatus.online ||
      connectivityStatus == ConnectivityStatus.limited;

  if (session == null || !canRunHeartbeat) {
    return null;
  }

  final notifier = ref.read(syncNotifierProvider.notifier);
  final coordinator = SyncHeartbeatCoordinator(runSyncCycle: notifier.runNow)
    ..start();

  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final syncStatusDetailsNotifierProvider =
    AsyncNotifierProvider<SyncStatusDetailsNotifier, SyncStatusDetails>(
      SyncStatusDetailsNotifier.new,
    );

class SyncStatusDetailsNotifier extends AsyncNotifier<SyncStatusDetails> {
  SyncStatusLocalDatasource get _datasource =>
      ref.read(syncStatusLocalDatasourceProvider);

  @override
  Future<SyncStatusDetails> build() {
    return _datasource.loadDetails();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_datasource.loadDetails);
  }

  Future<void> saveApiBaseUrl(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await resetApiBaseUrl();
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _datasource.saveApiBaseUrl(normalized);
      return _datasource.loadDetails();
    });
    ref.read(syncHeartbeatProvider)?.triggerSoon();
  }

  Future<void> resetApiBaseUrl() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _datasource.resetApiBaseUrl();
      return _datasource.loadDetails();
    });
    ref.read(syncHeartbeatProvider)?.triggerSoon();
  }

  Future<void> retryIssueOperations() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _datasource.retryIssueOperations();
      return _datasource.loadDetails();
    });
    ref.invalidate(syncNotifierProvider);
    ref.read(syncHeartbeatProvider)?.triggerSoon();
  }

  Future<void> retryOperation(String operationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _datasource.retryOperation(operationId);
      return _datasource.loadDetails();
    });
    ref.invalidate(syncNotifierProvider);
    ref.read(syncHeartbeatProvider)?.triggerSoon();
  }
}
