import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/entities/connectivity_status.dart';

class DeviceConnectivityDatasource {
  DeviceConnectivityDatasource({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<ConnectivityStatus> currentStatus() async {
    final results = await _connectivity.checkConnectivity();
    return mapConnectivityResults(results);
  }

  Stream<ConnectivityStatus> watchStatus() {
    return _connectivity.onConnectivityChanged
        .map(mapConnectivityResults)
        .distinct();
  }

  Stream<ConnectivityStatus> watchStatusWithInitialValue() async* {
    yield await currentStatus();
    yield* watchStatus();
  }
}

ConnectivityStatus mapConnectivityResults(List<ConnectivityResult> results) {
  if (results.isEmpty || results.contains(ConnectivityResult.none)) {
    return ConnectivityStatus.offline;
  }

  if (_containsReliableTransport(results)) {
    return ConnectivityStatus.online;
  }

  return ConnectivityStatus.limited;
}

bool _containsReliableTransport(List<ConnectivityResult> results) {
  return results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.mobile) ||
      results.contains(ConnectivityResult.ethernet) ||
      results.contains(ConnectivityResult.vpn);
}
