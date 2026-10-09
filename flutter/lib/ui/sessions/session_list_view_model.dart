import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/prefs/settings_repository.dart';
import '../../data/repository/session_repository.dart';

class SessionListViewModel extends ChangeNotifier {
  final SessionRepository sessionRepository;
  final SettingsRepository settingsRepository;

  SessionListViewModel({
    required this.sessionRepository,
    required this.settingsRepository,
  }) {
    _subs.add(sessionRepository.observeSessions().listen((list) {
      sessions = list;
      notifyListeners();
    }));
    _subs.add(settingsRepository.settings.listen((s) {
      configured = s.isConfigured;
      notifyListeners();
    }));
  }

  final _subs = <StreamSubscription<dynamic>>[];
  final _events = StreamController<String>.broadcast();

  Stream<String> get events => _events.stream;

  List<ChatSession> sessions = const [];
  bool configured = true;
  bool syncing = false;

  Future<String> createSession() => sessionRepository.create();

  Future<void> rename(String id, String title) =>
      sessionRepository.rename(id, title);

  void delete(String id) {
    unawaited(() async {
      final serverGone = await sessionRepository.deleteSynced(id);
      if (!serverGone) _events.add('已从本机删除，但服务端删除失败');
    }());
  }

  /// Pull every session the server knows about, including ones created outside
  /// this app.
  void syncAll() {
    if (syncing) return;
    unawaited(() async {
      syncing = true;
      notifyListeners();
      try {
        final count = await sessionRepository.syncAll();
        _events.add(count == 0 ? '没有可同步的会话' : '已同步 $count 个会话');
      } catch (error) {
        _events.add(
            '同步失败：${error.toString().replaceFirst(RegExp(r'^Exception: '), '')}');
      } finally {
        syncing = false;
        notifyListeners();
      }
    }());
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _events.close();
    super.dispose();
  }
}
