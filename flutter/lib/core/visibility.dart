import 'package:flutter/foundation.dart';

/// Process-level foreground state, fed from the root widget's lifecycle observer.
/// Used to decide whether a run-completion notification is useful at all.
class AppVisibility {
  bool isForeground = false;
}

/// The chat session currently on screen. RunManager suppresses the system
/// notification when the user is already watching the session that finished —
/// the live UI shows the outcome.
class ChatVisibility {
  String? foregroundSessionId;
}

/// Notification deep links: a session id waiting to be opened, set by the
/// notification tap handler and consumed by the root navigation.
class PendingNavigation extends ChangeNotifier {
  String? _sessionId;

  String? get sessionId => _sessionId;

  void push(String sessionId) {
    _sessionId = sessionId;
    notifyListeners();
  }

  void consume() {
    _sessionId = null;
  }
}
