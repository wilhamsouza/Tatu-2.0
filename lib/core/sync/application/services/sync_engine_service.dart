import '../../../auth/domain/entities/user_session.dart';
import '../../../database/app_database.dart';
import '../../../logging/app_logger.dart';
import '../../../networking/api_client.dart';
import '../../data/datasources/local/sync_inbox_local_datasource.dart';
import '../../data/datasources/local/sync_outbox_local_datasource.dart';
import '../../data/datasources/remote/sync_remote_datasource.dart';
import '../dtos/sync_run_summary.dart';

class SyncEngineService {
  SyncEngineService({
    required SyncOutboxLocalDatasource outboxLocalDatasource,
    required SyncInboxLocalDatasource inboxLocalDatasource,
    required SyncRemoteDatasource remoteDatasource,
    required AppDatabase database,
    required AppLogger logger,
  }) : _outboxLocalDatasource = outboxLocalDatasource,
       _inboxLocalDatasource = inboxLocalDatasource,
       _remoteDatasource = remoteDatasource,
       _database = database,
       _logger = logger;

  final SyncOutboxLocalDatasource _outboxLocalDatasource;
  final SyncInboxLocalDatasource _inboxLocalDatasource;
  final SyncRemoteDatasource _remoteDatasource;
  final AppDatabase _database;
  final AppLogger _logger;

  bool _isRunning = false;

  Future<SyncRunSummary> runOnce({
    required UserSession session,
    int outboxBatchSize = 20,
    int updatesLimit = 50,
  }) async {
    if (_isRunning) {
      return const SyncRunSummary();
    }

    _isRunning = true;
    try {
      await _database.appendSyncLog(
        level: 'info',
        message: 'Starting sync cycle.',
        context: <String, Object?>{
          'companyId': session.companyContext.companyId,
          'deviceId': session.deviceRegistration.deviceId,
        },
      );

      final operations = await _outboxLocalDatasource
          .loadOperationsForProcessing(limit: outboxBatchSize);

      var syncedOperations = 0;
      var failedOperations = 0;
      var conflictOperations = 0;
      var transportFailed = false;
      var updatesFailed = false;

      if (operations.isNotEmpty) {
        await _outboxLocalDatasource.markOperationsSending(
          operations.map((operation) => operation.operationId).toList(),
        );

        try {
          final results = await _remoteDatasource.sendOutbox(
            session: session,
            operations: operations,
          );
          final resultsByOperationId = <String, dynamic>{
            for (final result in results) result.operationId: result,
          };

          for (final operation in operations) {
            final result = resultsByOperationId[operation.operationId];
            if (result == null) {
              await _outboxLocalDatasource.markOperationFailed(
                operation: operation,
                errorMessage:
                    'Backend nao confirmou a operacao ${operation.operationId}.',
              );
              failedOperations += 1;
              continue;
            }

            switch (result.status) {
              case 'processed':
              case 'idempotent':
                await _outboxLocalDatasource.markOperationSynced(
                  operation: operation,
                  remoteData: result.data,
                );
                syncedOperations += 1;
                break;
              case 'conflict':
                await _outboxLocalDatasource.markOperationConflict(
                  operation: operation,
                  conflictType: result.conflictType ?? 'sync_conflict',
                  errorMessage:
                      result.error ??
                      'Conflito detectado durante a sincronizacao.',
                );
                conflictOperations += 1;
                break;
              case 'failed':
              case 'unsupported':
                await _outboxLocalDatasource.markOperationFailed(
                  operation: operation,
                  errorMessage:
                      result.error ??
                      'Falha ao sincronizar operacao ${operation.operationId}.',
                );
                failedOperations += 1;
                break;
            }
          }
        } on ApiException catch (error, stackTrace) {
          _logger.error('Falha remota ao enviar outbox.', error, stackTrace);
          transportFailed = true;
          for (final operation in operations) {
            await _outboxLocalDatasource.markOperationFailed(
              operation: operation,
              errorMessage: error.message,
            );
            failedOperations += 1;
          }
        } catch (error, stackTrace) {
          _logger.error(
            'Falha inesperada ao enviar outbox.',
            error,
            stackTrace,
          );
          transportFailed = true;
          for (final operation in operations) {
            await _outboxLocalDatasource.markOperationFailed(
              operation: operation,
              errorMessage: 'Falha inesperada durante o envio do outbox.',
            );
            failedOperations += 1;
          }
        }
      }

      var receivedUpdates = 0;
      var appliedUpdates = 0;
      if (!transportFailed) {
        try {
          final currentCursor = await _inboxLocalDatasource.loadCursor();
          final updatesResponse = await _remoteDatasource.fetchUpdates(
            session: session,
            cursor: currentCursor,
            limit: updatesLimit,
          );

          receivedUpdates = updatesResponse.updates.length;
          if (updatesResponse.updates.isNotEmpty) {
            await _inboxLocalDatasource.persistUpdates(updatesResponse.updates);
          }

          appliedUpdates = await _inboxLocalDatasource.applyPendingUpdates(
            nextCursor: updatesResponse.nextCursor,
          );
        } on ApiException catch (error, stackTrace) {
          _logger.error(
            'Falha remota ao buscar updates incrementais.',
            error,
            stackTrace,
          );
          updatesFailed = true;
          await _database.appendSyncLog(
            level: 'warning',
            message: 'Unable to fetch remote updates.',
            context: <String, Object?>{'message': error.message},
          );
        } catch (error, stackTrace) {
          _logger.error(
            'Falha inesperada ao buscar updates incrementais.',
            error,
            stackTrace,
          );
          updatesFailed = true;
          await _database.appendSyncLog(
            level: 'warning',
            message: 'Unexpected error while fetching remote updates.',
            context: <String, Object?>{'error': '$error'},
          );
        }
      }

      await _database.appendSyncLog(
        level: 'info',
        message: 'Sync cycle finished.',
        context: <String, Object?>{
          'processedOperations': operations.length,
          'syncedOperations': syncedOperations,
          'failedOperations': failedOperations,
          'conflictOperations': conflictOperations,
          'receivedUpdates': receivedUpdates,
          'appliedUpdates': appliedUpdates,
        },
      );

      return SyncRunSummary(
        processedOperations: operations.length,
        syncedOperations: syncedOperations,
        failedOperations: failedOperations,
        conflictOperations: conflictOperations,
        receivedUpdates: receivedUpdates,
        appliedUpdates: appliedUpdates,
        transportFailed: transportFailed,
        updatesFailed: updatesFailed,
      );
    } finally {
      _isRunning = false;
    }
  }
}
