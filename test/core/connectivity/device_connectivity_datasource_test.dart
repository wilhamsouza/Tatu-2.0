import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatuzin/core/connectivity/data/datasources/device_connectivity_datasource.dart';
import 'package:tatuzin/core/connectivity/domain/entities/connectivity_status.dart';

void main() {
  test('maps none to offline', () {
    expect(
      mapConnectivityResults(const <ConnectivityResult>[
        ConnectivityResult.none,
      ]),
      ConnectivityStatus.offline,
    );
  });

  test('maps wifi and mobile transports to online', () {
    expect(
      mapConnectivityResults(const <ConnectivityResult>[
        ConnectivityResult.wifi,
      ]),
      ConnectivityStatus.online,
    );
    expect(
      mapConnectivityResults(const <ConnectivityResult>[
        ConnectivityResult.mobile,
      ]),
      ConnectivityStatus.online,
    );
    expect(
      mapConnectivityResults(const <ConnectivityResult>[
        ConnectivityResult.vpn,
      ]),
      ConnectivityStatus.online,
    );
  });

  test('maps unsupported or secondary transports to limited', () {
    expect(
      mapConnectivityResults(const <ConnectivityResult>[
        ConnectivityResult.bluetooth,
      ]),
      ConnectivityStatus.limited,
    );
    expect(
      mapConnectivityResults(const <ConnectivityResult>[
        ConnectivityResult.other,
      ]),
      ConnectivityStatus.limited,
    );
  });
}
