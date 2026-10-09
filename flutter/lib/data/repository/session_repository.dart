import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import '../local/rows.dart';
import '../models.dart';
import '../remote/hermes_api.dart';

class SessionRepository {
  final HermesDatabase db;
  final HermesApi api;

  SessionRepository(this.db, this.api);

  Stream<List<ChatSession>> observeSessions() =>
      db.observeSessions().map((list) => list.map(_toDomain).toList());

  Stream<ChatSession?> observeSession(String id) =>
      db.observeSession(id).map((s) => s == null ? null : _toDomain(s));

  Future<ChatSession?> get(String id) async {
    final s = await db.getSession(id);
    return s == null ? null : _toDomain(s);
  }

  Future<String> create([String title = '新会话']) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const uuid = Uuid();
    final id = 'hm-${uuid.v4().replaceAll('-', '').substring(0, 24)}';
    await db.upsertSession(LocalSession(
        id: id, title: title, createdAt: now, updatedAt: now));
    return id;
  }

  Future<String> ensure(String id) async {
    final existing = await db.getSession(id);
    if (existing == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.upsertSession(
          LocalSession(id: id, title: '新会话', createdAt: now, updatedAt: now));
    }
    return id;
  }

  Future<void> rename(String id, String title) async {
    final clean = title.trim().isNotEmpty ? title.trim() : '未命名会话';
    await db.renameSession(
        id, clean, DateTime.now().millisecondsSinceEpoch);
  }

  /// Delete locally *and* on the server. Returns true when the server also no
  /// longer has the session (a 404 counts as success). Local data is removed
  /// regardless so the UI always reacts.
  Future<bool> deleteSynced(String id) async {
    var serverGone = false;
    try {
      await api.deleteSession(id);
      serverGone = true;
    } on DioException catch (e) {
      serverGone = e.response?.statusCode == 404;
    } catch (_) {
      serverGone = false;
    }
    await db.deleteMessagesForSession(id);
    await db.deleteRunsForSession(id);
    await db.deleteSession(id);
    return serverGone;
  }

  /// Pull every session the server knows about (including ones created outside
  /// this app) and merge them into the local list. New rows are inserted;
  /// existing rows keep their local title unless it is still the default, so a
  /// local rename is not clobbered. Returns the count merged.
  Future<int> syncAll() async {
    const limit = 200;
    var offset = 0;
    var merged = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    while (true) {
      final page = await api.listSessions(limit: limit, offset: offset);
      if (page.data.isEmpty) break;
      for (final server in page.data) {
        if (server.id.isEmpty) continue;
        // Internal sub-agent / hidden sessions are not user conversations.
        if (server.hidden ||
            server.isInternalChild ||
            (server.parentSessionId?.isNotEmpty ?? false)) {
          continue;
        }
        final startedAt = _secondsToMillis(server.startedAt) ?? now;
        final lastActive =
            _secondsToMillis(server.lastActive ?? server.startedAt) ?? startedAt;
        final serverTitle =
            (server.title ?? '').trim().isNotEmpty ? server.title!.trim() : '新会话';
        final preview = (server.preview ?? '').trim();
        final existing = await db.getSession(server.id);
        if (existing == null) {
          await db.upsertSession(LocalSession(
            id: server.id,
            title: serverTitle,
            createdAt: startedAt,
            updatedAt: lastActive,
            preview: _truncate(preview, 120),
          ));
        } else {
          final title = (existing.title.isEmpty || existing.title == '新会话')
              ? serverTitle
              : existing.title;
          await db.updateSessionMeta(
            server.id,
            title,
            existing.updatedAt > lastActive ? existing.updatedAt : lastActive,
            _truncate(preview.isNotEmpty ? preview : existing.preview, 120),
          );
        }
        merged++;
      }
      if (!page.hasMore) break;
      offset += limit;
    }
    return merged;
  }

  Future<void> touchPreview(String id, String preview) =>
      db.touchSession(id, DateTime.now().millisecondsSinceEpoch,
          _truncate(preview, 120));

  static int? _secondsToMillis(double? seconds) {
    final millis = ((seconds ?? 0) * 1000).round();
    return millis > 0 ? millis : null;
  }

  static String _truncate(String s, int max) => s.length <= max ? s : s.substring(0, max);

  static ChatSession _toDomain(LocalSession s) => ChatSession(
        id: s.id,
        title: s.title,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
        preview: s.preview,
        activeRunId: s.activeRunId,
        activeRunState: s.activeRunState == null
            ? null
            : RunState.from(s.activeRunState),
      );
}
