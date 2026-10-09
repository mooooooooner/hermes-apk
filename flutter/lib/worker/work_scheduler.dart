import 'dart:io';

import 'package:workmanager/workmanager.dart';

import 'reconcile_dispatcher.dart';

/// Registers the background reconciliation jobs (Android only — Windows has no
/// equivalent of WorkManager; there we reconcile on launch / window focus).
class WorkScheduler {
  bool _periodicDone = false;

  Future<void> ensurePeriodicScheduled() async {
    if (_periodicDone || !Platform.isAndroid) return;
    _periodicDone = true;
    try {
      await Workmanager().registerPeriodicTask(
        reconcilePeriodicUniqueName,
        reconcileTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.exponential,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {}
  }

  void scheduleOneTimeReconcile() {
    if (!Platform.isAndroid) return;
    unawaitedSafe();
  }

  Future<void> _scheduleOneTime() async {
    try {
      await Workmanager().registerOneOffTask(
        reconcileOneTimeUniqueName,
        reconcileTaskName,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.exponential,
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (_) {}
  }

  void unawaitedSafe() {
    Future<void>(() => _scheduleOneTime());
  }
}
