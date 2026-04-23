import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/device_connectivity_datasource.dart';
import '../../domain/entities/connectivity_status.dart';

final deviceConnectivityDatasourceProvider =
    Provider<DeviceConnectivityDatasource>((ref) {
      return DeviceConnectivityDatasource();
    });

final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  return ref
      .read(deviceConnectivityDatasourceProvider)
      .watchStatusWithInitialValue()
      .distinct();
});

final currentConnectivityStatusProvider = Provider<ConnectivityStatus?>((ref) {
  return ref
      .watch(connectivityStatusProvider)
      .maybeWhen(data: (status) => status, orElse: () => null);
});
