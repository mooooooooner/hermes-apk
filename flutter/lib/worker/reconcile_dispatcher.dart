import 'package:workmanager/workmanager.dart';

import '../di.dart';

/// Task names used by [WorkScheduler] and the dispatcher below.
const reconcileTaskName = 'runReconcile';
const reconcilePeriodicUniqueName = 'runReconcilePeriodic';
const reconcileOneTimeUniqueName = 'runReconcileOnce';

/// Runs in its own isolate (WorkManager spawns one on Android), so the whole
/// dependency graph is rebuilt from scratch — no shared memory with the UI
/// isolate. Reconciliation is exactly what the app does when it returns to the
/// foreground: poll the status of every locally-known unfinished run and either
/// finalise or re-attach to it.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Di.initForBackground();
      await Di.runManager.reconcileAll();
      return true;
    } catch (_) {
      return false;
    }
  });
}
