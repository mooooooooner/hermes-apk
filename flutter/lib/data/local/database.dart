import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import 'rows.dart';

part 'database.g.dart';

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get preview => text().withDefault(const Constant(''))();
  TextColumn get activeRunId => text().nullable()();
  TextColumn get activeRunState => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  TextColumn get role => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get reasoning => text().withDefault(const Constant(''))();
  TextColumn get status => text()();
  TextColumn get runId => text().nullable()();
  IntColumn get seq => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get attachments => text().withDefault(const Constant('[]'))();
  TextColumn get toolEvents => text().withDefault(const Constant('[]'))();
  TextColumn get segments => text().withDefault(const Constant('[]'))();
  TextColumn get error => text().nullable()();
  TextColumn get usage => text().nullable()();
  IntColumn get serverId => integer().nullable()();
}

class Runs extends Table {
  TextColumn get runId => text()();
  TextColumn get sessionId => text()();
  IntColumn get userMessageId => integer().nullable()();
  IntColumn get assistantMessageId => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get output => text().nullable()();
  TextColumn get error => text().nullable()();
  TextColumn get lastEvent => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get notified => boolean().withDefault(const Constant(false))();
  TextColumn get usage => text().nullable()();
}

@DriftDatabase(tables: [Sessions, Messages, Runs])
class HermesDatabase extends _$HermesDatabase {
  HermesDatabase(super.e);

  HermesDatabase.open()
      : super(LazyDatabase(() async {
          final dir = await getApplicationSupportDirectory();
          return NativeDatabase.createInBackground(
            File(p.join(dir.path, 'hermes.db')),
          );
        }));

  @override
  int get schemaVersion => 1;

  // =========================================================================
  // Sessions
  // =========================================================================

  Stream<List<LocalSession>> observeSessions() {
    return (select(sessions)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch()
        .map((rows) => rows.map(_sessionToDomain).toList());
  }

  Stream<LocalSession?> observeSession(String id) {
    return (select(sessions)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _sessionToDomain(row));
  }

  Future<LocalSession?> getSession(String id) async {
    final row = await (select(sessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _sessionToDomain(row);
  }

  Future<void> upsertSession(LocalSession session) => into(sessions)
      .insertOnConflictUpdate(_sessionFromDomain(session));

  Future<void> renameSession(String id, String title, int updatedAt) =>
      (update(sessions)..where((t) => t.id.equals(id)))
          .write(SessionsCompanion(title: Value(title), updatedAt: Value(updatedAt)));

  Future<void> touchSession(String id, int updatedAt, String preview) =>
      (update(sessions)..where((t) => t.id.equals(id))).write(
          SessionsCompanion(updatedAt: Value(updatedAt), preview: Value(preview)));

  Future<void> updateSessionMeta(
          String id, String title, int updatedAt, String preview) =>
      (update(sessions)..where((t) => t.id.equals(id))).write(
          SessionsCompanion(
              title: Value(title),
              updatedAt: Value(updatedAt),
              preview: Value(preview)));

  Future<void> setActiveRun(String id, String? runId, String? state) =>
      (update(sessions)..where((t) => t.id.equals(id))).write(
          SessionsCompanion(activeRunId: Value(runId), activeRunState: Value(state)));

  Future<void> deleteSession(String id) =>
      (delete(sessions)..where((t) => t.id.equals(id))).go();

  // =========================================================================
  // Messages
  // =========================================================================

  /// Newest first: the chat renders bottom-up (reversed list), so item 0 is the
  /// newest turn.
  Stream<List<LocalMessage>> observeMessages(String sessionId) {
    return (select(messages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.seq),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch()
        .map((rows) => rows.map(_messageToDomain).toList());
  }

  Future<List<LocalMessage>> listMessages(String sessionId) async {
    final rows = await (select(messages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.seq),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
    return rows.map(_messageToDomain).toList();
  }

  Future<LocalMessage?> getMessage(int id) async {
    final row = await (select(messages)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _messageToDomain(row);
  }

  Future<int> maxSeq(String sessionId) async {
    final expr = messages.seq.max();
    final query = selectOnly(messages)
      ..addColumns([expr])
      ..where(messages.sessionId.equals(sessionId));
    final row = await query.getSingle();
    return row.read(expr) ?? 0;
  }

  /// Placeholders persisted as PENDING but never bound to a run (killed mid-send).
  Future<List<LocalMessage>> pendingWithoutRun() async {
    final rows = await (select(messages)
          ..where((t) =>
              t.status.equals('PENDING') & t.runId.isNull()))
        .get();
    return rows.map(_messageToDomain).toList();
  }

  Future<int> insertMessage(LocalMessage message) async =>
      into(messages).insert(_messageFromDomain(message, forInsert: true));

  Future<void> updateMessage(LocalMessage message) =>
      (update(messages)..where((t) => t.id.equals(message.id)))
          .write(_messageCompanion(message));

  Future<void> updateProgress(
    int id, {
    required String content,
    required String reasoning,
    required String status,
    required String toolEvents,
    required String segments,
    required String? error,
    required String? usage,
  }) =>
      (update(messages)..where((t) => t.id.equals(id))).write(MessagesCompanion(
        content: Value(content),
        reasoning: Value(reasoning),
        status: Value(status),
        toolEvents: Value(toolEvents),
        segments: Value(segments),
        error: Value(error),
        usage: Value(usage),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<void> bindRun(int id, String runId, String status) =>
      (update(messages)..where((t) => t.id.equals(id)))
          .write(MessagesCompanion(runId: Value(runId), status: Value(status)));

  Future<void> setMessageStatus(int id, String status) =>
      (update(messages)..where((t) => t.id.equals(id)))
          .write(MessagesCompanion(status: Value(status)));

  Future<void> deleteMessagesForSession(String sessionId) =>
      (delete(messages)..where((t) => t.sessionId.equals(sessionId))).go();

  /// Everything after a user turn, including the assistant row sharing its seq.
  Future<void> deleteMessagesAfter(String sessionId, int seq) =>
      customUpdate(
        'DELETE FROM messages WHERE session_id = ? '
        'AND (seq > ? OR (seq = ? AND role = \'ASSISTANT\'))',
        variables: [Variable(sessionId), Variable(seq), Variable(seq)],
      );

  Future<void> deleteMessage(int id) =>
      (delete(messages)..where((t) => t.id.equals(id))).go();

  /// Joined message+run watch so the chat list re-emits when either side
  /// changes (mirrors the Kotlin `combine(messageDao.observe, runDao.observe)`).
  Stream<List<(LocalMessage, RunState?)>> observeChatMessages(String sessionId) {
    final query = select(messages).join([
      leftOuterJoin(runs, runs.runId.equalsExp(messages.runId)),
    ])
      ..where(messages.sessionId.equals(sessionId))
      ..orderBy([
        OrderingTerm.desc(messages.seq),
        OrderingTerm.desc(messages.createdAt),
      ]);
    return query.watch().map((rows) => [
          for (final row in rows)
            (
              _messageToDomain(row.readTable(messages)),
              row.readTableOrNull(runs) == null
                  ? null
                  : RunState.from(row.readTableOrNull(runs)!.status),
            )
        ]);
  }

  // =========================================================================
  // Runs
  // =========================================================================

  Stream<List<LocalRun>> observeRunsForSession(String sessionId) {
    return (select(runs)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_runToDomain).toList());
  }

  Future<void> upsertRun(LocalRun run) =>
      into(runs).insertOnConflictUpdate(_runFromDomain(run));

  Future<LocalRun?> getRun(String runId) async {
    final row = await (select(runs)..where((t) => t.runId.equals(runId)))
        .getSingleOrNull();
    return row == null ? null : _runToDomain(row);
  }

  Future<List<LocalRun>> activeRuns() async {
    final rows = await (select(runs)
          ..where((t) => t.status.isNotIn(
              ['COMPLETED', 'FAILED', 'CANCELLED', 'INTERRUPTED'])))
        .get();
    return rows.map(_runToDomain).toList();
  }

  Future<void> updateRunStatus(
    String runId, {
    required String status,
    String? output,
    String? error,
    String? lastEvent,
    String? usage,
    int? updatedAt,
  }) =>
      (update(runs)..where((t) => t.runId.equals(runId))).write(RunsCompanion(
        status: Value(status),
        output: Value(output),
        error: Value(error),
        lastEvent: Value(lastEvent),
        usage: Value(usage),
        updatedAt: Value(updatedAt ?? DateTime.now().millisecondsSinceEpoch),
      ));

  /// Claims the notification slot. Returns true when this call transitioned
  /// notified 0 -> 1.
  Future<bool> markNotified(String runId) async {
    final count = await (update(runs)..where((t) =>
            t.runId.equals(runId) & t.notified.equals(false)))
        .write(const RunsCompanion(notified: Value(true)));
    return count > 0;
  }

  Future<void> deleteRunsForSession(String sessionId) =>
      (delete(runs)..where((t) => t.sessionId.equals(sessionId))).go();

  // =========================================================================
  // Mappers
  // =========================================================================

  static LocalSession _sessionToDomain(Session row) => LocalSession(
        id: row.id,
        title: row.title,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        preview: row.preview,
        activeRunId: row.activeRunId,
        activeRunState: row.activeRunState,
      );

  static SessionsCompanion _sessionFromDomain(LocalSession s) =>
      SessionsCompanion(
        id: Value(s.id),
        title: Value(s.title),
        createdAt: Value(s.createdAt),
        updatedAt: Value(s.updatedAt),
        preview: Value(s.preview),
        activeRunId: Value(s.activeRunId),
        activeRunState: Value(s.activeRunState),
      );

  static LocalMessage _messageToDomain(Message row) => LocalMessage(
        id: row.id,
        sessionId: row.sessionId,
        role: messageRoleFrom(row.role),
        content: row.content,
        reasoning: row.reasoning,
        status: messageStatusFrom(row.status),
        runId: row.runId,
        seq: row.seq,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        attachments: AttachmentListJson.decode(row.attachments),
        toolEvents: ToolEventListJson.decode(row.toolEvents),
        segments: SegmentListJson.decode(row.segments),
        error: row.error,
        usage: UsageJson.decode(row.usage),
        serverId: row.serverId,
      );

  static MessagesCompanion _messageFromDomain(LocalMessage m,
          {bool forInsert = false}) =>
      MessagesCompanion(
        // A non-zero id is kept so a history sync can re-insert rows under
        // their original ids (stable keys keep list items mounted, no flash).
        id: forInsert && m.id == 0 ? const Value.absent() : Value(m.id),
        sessionId: Value(m.sessionId),
        role: Value(m.role.name.toUpperCase()),
        content: Value(m.content),
        reasoning: Value(m.reasoning),
        status: Value(m.status.name.toUpperCase()),
        runId: Value(m.runId),
        seq: Value(m.seq),
        createdAt: Value(m.createdAt),
        updatedAt: Value(m.updatedAt),
        attachments: Value(AttachmentListJson.encode(m.attachments)),
        toolEvents: Value(ToolEventListJson.encode(m.toolEvents)),
        segments: Value(SegmentListJson.encode(m.segments)),
        error: Value(m.error),
        usage: Value(UsageJson.encode(m.usage)),
        serverId: Value(m.serverId),
      );

  static MessagesCompanion _messageCompanion(LocalMessage m) =>
      _messageFromDomain(m);

  static LocalRun _runToDomain(Run row) => LocalRun(
        runId: row.runId,
        sessionId: row.sessionId,
        userMessageId: row.userMessageId,
        assistantMessageId: row.assistantMessageId,
        status: RunState.from(row.status),
        output: row.output,
        error: row.error,
        lastEvent: row.lastEvent,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        notified: row.notified,
        usage: UsageJson.decode(row.usage),
      );

  static RunsCompanion _runFromDomain(LocalRun r) => RunsCompanion(
        runId: Value(r.runId),
        sessionId: Value(r.sessionId),
        userMessageId: Value(r.userMessageId),
        assistantMessageId: Value(r.assistantMessageId),
        status: Value(r.status.name.toUpperCase()),
        output: Value(r.output),
        error: Value(r.error),
        lastEvent: Value(r.lastEvent),
        createdAt: Value(r.createdAt),
        updatedAt: Value(r.updatedAt),
        notified: Value(r.notified),
        usage: Value(UsageJson.encode(r.usage)),
      );
}
