import '../dtos/sync_run_summary.dart';

class SyncHeartbeatPolicy {
  const SyncHeartbeatPolicy({
    this.resumeDelay = const Duration(seconds: 2),
    this.busyDelay = const Duration(seconds: 20),
    this.issueDelay = const Duration(seconds: 45),
    this.updatesFailureDelay = const Duration(seconds: 60),
    this.transportFailureDelay = const Duration(minutes: 2),
    this.idleDelay = const Duration(seconds: 90),
  });

  final Duration resumeDelay;
  final Duration busyDelay;
  final Duration issueDelay;
  final Duration updatesFailureDelay;
  final Duration transportFailureDelay;
  final Duration idleDelay;

  Duration nextDelayFor(SyncRunSummary summary) {
    if (summary.transportFailed) {
      return transportFailureDelay;
    }

    if (summary.hasIssues) {
      return issueDelay;
    }

    if (summary.hadActivity) {
      return busyDelay;
    }

    if (summary.updatesFailed) {
      return updatesFailureDelay;
    }

    return idleDelay;
  }
}
