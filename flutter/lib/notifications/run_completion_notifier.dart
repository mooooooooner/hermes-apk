import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

import '../core/visibility.dart';

/// System notification when a run finishes while its session is not on screen.
/// Tapping it deep-links into the session (see [PendingNavigation]).
///
/// Platform split: flutter_local_notifications has no Windows implementation,
/// so Windows toasts go through local_notifier.
class RunCompletionNotifier {
  final PendingNavigation pendingNavigation;

  RunCompletionNotifier(this.pendingNavigation);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextNotifyId = 1000;

  Future<void> ensureInitialized() async {
    if (_ready) return;
    try {
      if (Platform.isAndroid) {
        const androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        await _plugin.initialize(
          const InitializationSettings(android: androidSettings),
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            if (payload != null && payload.isNotEmpty) {
              pendingNavigation.push(payload);
            }
          },
        );
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        await android
            ?.createNotificationChannel(const AndroidNotificationChannel(
          'run_completion',
          '任务完成通知',
          description: '后台任务完成或失败时提醒',
          importance: Importance.defaultImportance,
        ));
      } else if (Platform.isWindows) {
        await LocalNotifier.instance.setup(appName: 'Hermes');
      }
      _ready = true;
    } catch (_) {
      // Notifications are best-effort: never block startup.
    }
  }

  /// True when the app was launched from a notification tap (Android only —
  /// local_notifier exposes no launch-details API).
  Future<String?> launchSessionId() async {
    if (!Platform.isAndroid) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) return payload;
    } catch (_) {}
    return null;
  }

  Future<void> notifyRun({
    required String sessionId,
    required String title,
    required String message,
    required bool success,
  }) async {
    await ensureInitialized();
    if (!_ready) return;
    final displayTitle = success ? '$title · 已完成' : '$title · 失败';
    if (Platform.isWindows) {
      final notification = LocalNotification(
        title: displayTitle,
        body: message,
      );
      notification.onClick = () => pendingNavigation.push(sessionId);
      notification.show();
      return;
    }
    final id = _nextNotifyId++;
    final androidDetails = AndroidNotificationDetails(
      'run_completion',
      '任务完成通知',
      channelDescription: '后台任务完成或失败时提醒',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(message),
    );
    await _plugin.show(
      id,
      displayTitle,
      message,
      NotificationDetails(android: androidDetails),
      payload: sessionId,
    );
  }
}
