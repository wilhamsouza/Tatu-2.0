import 'dart:async';

import 'package:flutter/widgets.dart';

import '../dtos/sync_run_summary.dart';
import 'sync_heartbeat_policy.dart';

typedef RunSyncCycle = Future<SyncRunSummary> Function();

class SyncHeartbeatCoordinator with WidgetsBindingObserver {
  SyncHeartbeatCoordinator({
    required RunSyncCycle runSyncCycle,
    SyncHeartbeatPolicy? policy,
  }) : _runSyncCycle = runSyncCycle,
       _policy = policy ?? const SyncHeartbeatPolicy();

  final RunSyncCycle _runSyncCycle;
  final SyncHeartbeatPolicy _policy;

  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _running = false;
  bool _runRequested = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  void start() {
    if (_started || _disposed) {
      return;
    }

    _started = true;
    WidgetsBinding.instance.addObserver(this);
    triggerSoon(_policy.resumeDelay);
  }

  void triggerSoon([Duration delay = Duration.zero]) {
    if (_disposed || !_isForeground) {
      return;
    }

    if (_running) {
      _runRequested = true;
      return;
    }

    _schedule(delay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (_isForeground) {
      triggerSoon(_policy.resumeDelay);
      return;
    }

    _cancelTimer();
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _cancelTimer();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  bool get _isForeground =>
      _lifecycleState == AppLifecycleState.resumed ||
      _lifecycleState == AppLifecycleState.inactive;

  void _schedule(Duration delay) {
    _cancelTimer();
    _timer = Timer(delay, _handleTick);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _handleTick() async {
    if (_disposed || _running || !_isForeground) {
      return;
    }

    _running = true;
    _runRequested = false;

    try {
      final summary = await _runSyncCycle();
      if (_disposed || !_isForeground) {
        return;
      }

      if (_runRequested) {
        _schedule(Duration.zero);
        return;
      }

      _schedule(_policy.nextDelayFor(summary));
    } catch (_) {
      if (_disposed || !_isForeground) {
        return;
      }

      _schedule(_policy.transportFailureDelay);
    } finally {
      _running = false;
    }
  }
}
