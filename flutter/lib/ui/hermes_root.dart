import 'dart:async';

import 'package:flutter/material.dart';

import '../data/prefs/settings_repository.dart';
import '../di.dart';
import 'chat/chat_screen.dart';
import 'sessions/session_list_screen.dart';
import 'settings/settings_screen.dart';
import 'theme/theme.dart';

/// Root widget: theme + navigation + lifecycle-driven reconciliation, ported
/// from HermesRoot.kt / MainActivity.kt.
class HermesRoot extends StatefulWidget {
  const HermesRoot({super.key});

  @override
  State<HermesRoot> createState() => _HermesRootState();
}

class _HermesRootState extends State<HermesRoot> with WidgetsBindingObserver {
  StreamSubscription<AppSettings>? _settingsSub;
  AppSettings _settings = const AppSettings();
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _navigatingFromNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsSub = Di.settings.settings.listen((s) {
      if (s.themeMode != _settings.themeMode ||
          s.dynamicColor != _settings.dynamicColor) {
        setState(() => _settings = s);
      } else {
        _settings = s;
      }
    });
    _settings = Di.settings.snapshot();
    // Anything the server finished while we were gone is reconciled on entry.
    unawaited(Di.runManager.reconcileAll());
    // Deep link when the app was launched by tapping a completion notification.
    Di.notifier.launchSessionId().then((sessionId) {
      if (sessionId != null && sessionId.isNotEmpty) {
        _openSession(sessionId);
      }
    });
    // Deep links from notification taps while the app is running.
    Di.pendingNavigation.addListener(_onPendingNavigation);
  }

  void _onPendingNavigation() {
    final sessionId = Di.pendingNavigation.sessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      _openSession(sessionId);
    }
  }

  void _openSession(String sessionId) {
    if (_navigatingFromNotification) return;
    _navigatingFromNotification = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _navigatingFromNotification = false;
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;
      // Pop back to the list, then open the session on top.
      navigator.popUntil((route) => route.isFirst);
      unawaited(navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ChatRoute(
            sessionId: sessionId,
            onBack: () => navigator.pop(),
          ),
        ),
      ));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    final wasForeground = Di.appVisibility.isForeground;
    Di.appVisibility.isForeground = foreground;
    if (foreground && !wasForeground) {
      // Returning to the app: reconcile runs that finished meanwhile. On
      // Windows this is also the main recovery path (no background worker).
      unawaited(Di.runManager.reconcileAll());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Di.pendingNavigation.removeListener(_onPendingNavigation);
    _settingsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HermesTheme(
      themeMode: _settings.themeMode,
      dynamicColor: _settings.dynamicColor,
      child: MaterialApp(
        title: 'Hermes',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        home: SessionListRoute(
          onOpenSession: (sessionId) {
            _navigatorKey.currentState?.push(
              MaterialPageRoute<void>(
                builder: (_) => ChatRoute(
                  sessionId: sessionId,
                  onBack: () => _navigatorKey.currentState?.pop(),
                ),
              ),
            );
          },
          onOpenSettings: () {
            _navigatorKey.currentState?.push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsRoute(
                  onBack: () => _navigatorKey.currentState?.pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
