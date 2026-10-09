import 'dart:io';

import 'package:workmanager/workmanager.dart';

import 'core/visibility.dart';
import 'data/local/database.dart';
import 'data/prefs/settings_repository.dart';
import 'data/remote/files_api.dart';
import 'data/remote/hermes_api.dart';
import 'data/remote/run_event_stream.dart';
import 'data/repository/chat_repository.dart';
import 'data/repository/file_service_repository.dart';
import 'data/repository/run_manager.dart';
import 'data/repository/session_repository.dart';
import 'notifications/run_completion_notifier.dart';
import 'worker/reconcile_dispatcher.dart';
import 'worker/work_scheduler.dart';

/// Hand-rolled service locator, mirroring the Kotlin AppModule. One graph for
/// the UI isolate; the background dispatcher builds its own via
/// [initForBackground] (isolates share no memory).
class Di {
  static late final SettingsRepository settings;
  static late final HermesDatabase db;
  static late final HermesApi api;
  static late final FilesApi filesApi;
  static late final RunEventStream eventStream;
  static late final FileServiceRepository fileService;
  static late final RunCompletionNotifier notifier;
  static late final WorkScheduler workScheduler;
  static late final AppVisibility appVisibility;
  static late final ChatVisibility chatVisibility;
  static late final PendingNavigation pendingNavigation;
  static late final RunManager runManager;
  static late final SessionRepository sessionRepository;
  static late final ChatRepository chatRepository;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    pendingNavigation = PendingNavigation();
    settings = await SettingsRepository.create();
    db = HermesDatabase.open();
    api = HermesApi(settings);
    filesApi = FilesApi(settings);
    eventStream = RunEventStream(settings);
    fileService = FileServiceRepository(filesApi, settings);
    notifier = RunCompletionNotifier(pendingNavigation);
    workScheduler = WorkScheduler();
    appVisibility = AppVisibility();
    chatVisibility = ChatVisibility();
    runManager = RunManager(
      api: api,
      eventStream: eventStream,
      db: db,
      notifier: notifier,
      workScheduler: workScheduler,
      appVisibility: appVisibility,
      chatVisibility: chatVisibility,
    );
    sessionRepository = SessionRepository(db, api);
    chatRepository = ChatRepository(
      api: api,
      db: db,
      settings: settings,
      runManager: runManager,
      fileService: fileService,
      workScheduler: workScheduler,
    );

    await notifier.ensureInitialized();
    if (Platform.isAndroid) {
      try {
        await Workmanager().initialize(callbackDispatcher);
      } catch (_) {}
      await workScheduler.ensurePeriodicScheduled();
    }
  }

  /// Subset for the background reconcile isolate: no WorkManager registration,
  /// no periodic scheduling (we ARE the job).
  static Future<void> initForBackground() async {
    if (_initialized) return;
    _initialized = true;

    pendingNavigation = PendingNavigation();
    settings = await SettingsRepository.create();
    db = HermesDatabase.open();
    api = HermesApi(settings);
    filesApi = FilesApi(settings);
    eventStream = RunEventStream(settings);
    fileService = FileServiceRepository(filesApi, settings);
    notifier = RunCompletionNotifier(pendingNavigation);
    workScheduler = WorkScheduler();
    appVisibility = AppVisibility();
    chatVisibility = ChatVisibility();
    runManager = RunManager(
      api: api,
      eventStream: eventStream,
      db: db,
      notifier: notifier,
      workScheduler: workScheduler,
      appVisibility: appVisibility,
      chatVisibility: chatVisibility,
    );
    sessionRepository = SessionRepository(db, api);
    chatRepository = ChatRepository(
      api: api,
      db: db,
      settings: settings,
      runManager: runManager,
      fileService: fileService,
      workScheduler: workScheduler,
    );
  }
}
