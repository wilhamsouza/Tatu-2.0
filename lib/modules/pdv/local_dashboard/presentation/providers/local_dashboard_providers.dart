import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers/database_providers.dart';
import '../../application/dtos/local_dashboard_snapshot.dart';
import '../../data/datasources/local/local_dashboard_local_datasource.dart';

final localDashboardLocalDatasourceProvider =
    Provider<LocalDashboardLocalDatasource>((ref) {
      return LocalDashboardLocalDatasource(
        database: ref.read(appDatabaseProvider),
      );
    });

final localDashboardSnapshotProvider =
    FutureProvider.family<LocalDashboardSnapshot, String>((
      ref,
      cashSessionLocalId,
    ) {
      return ref
          .read(localDashboardLocalDatasourceProvider)
          .loadSnapshotForCashSession(cashSessionLocalId);
    });
