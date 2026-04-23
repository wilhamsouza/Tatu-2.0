import 'package:flutter_test/flutter_test.dart';
import 'package:tatuzin/core/sync/application/dtos/sync_run_summary.dart';
import 'package:tatuzin/core/sync/application/services/sync_heartbeat_policy.dart';

void main() {
  const policy = SyncHeartbeatPolicy();

  test('uses transport backoff after connectivity failure', () {
    const summary = SyncRunSummary(transportFailed: true, failedOperations: 2);

    expect(policy.nextDelayFor(summary), policy.transportFailureDelay);
  });

  test('uses issue cadence when there are conflicts or business failures', () {
    const summary = SyncRunSummary(conflictOperations: 1);

    expect(policy.nextDelayFor(summary), policy.issueDelay);
  });

  test('uses busy cadence when sync is making progress', () {
    const summary = SyncRunSummary(
      processedOperations: 3,
      syncedOperations: 2,
      appliedUpdates: 1,
    );

    expect(policy.nextDelayFor(summary), policy.busyDelay);
  });

  test('uses updates failure cadence when only remote updates fail', () {
    const summary = SyncRunSummary(updatesFailed: true);

    expect(policy.nextDelayFor(summary), policy.updatesFailureDelay);
  });

  test('uses idle cadence when there is no work and no errors', () {
    const summary = SyncRunSummary();

    expect(policy.nextDelayFor(summary), policy.idleDelay);
  });
}
