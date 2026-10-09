import 'dart:async';
import 'dart:convert';

import '../../core/visibility.dart';
import '../../notifications/run_completion_notifier.dart';
import '../../worker/work_scheduler.dart';
import '../local/database.dart';
import '../local/rows.dart';
import '../models.dart';
import '../remote/dtos.dart';
import '../remote/hermes_api.dart';
import '../remote/run_event_stream.dart';
import 'history_folder.dart';

/// Owns the lifecycle of async Hermes runs. This is the heart of the "close the
/// app and come back" guarantee:
///
///  1. a run is persisted before we start streaming;
///  2. every event is written through to the database so the UI can render it
///     (or restore it) at any time;
///  3. if the process dies the server keeps working — [reconcileAll] re-attaches
///     or finalises runs when the app comes back.
///
/// Hermes runs an agent loop, so one run can contain several rounds of
/// `思维链 -> toolcall -> 正文`. The stream is folded into an ordered list of
/// [MessageSegment]s (see [StreamState]) instead of a single flat
/// reasoning/tool/text blob, which keeps the timeline faithful during streaming
/// *and* after a server-history sync.
class RunManager {
  final HermesApi api;
  final RunEventStream eventStream;
  final HermesDatabase db;
  final RunCompletionNotifier notifier;
  final WorkScheduler workScheduler;
  final AppVisibility appVisibility;
  final ChatVisibility chatVisibility;

  RunManager({
    required this.api,
    required this.eventStream,
    required this.db,
    required this.notifier,
    required this.workScheduler,
    required this.appVisibility,
    required this.chatVisibility,
  });

  final Map<String, _RunJob> _jobs = {};
  bool _reconcileBusy = false;

  /// Placeholder message ids for which a `POST /v1/runs` is currently in
  /// flight. A placeholder exists as `PENDING` with `runId == null` for the
  /// whole submit window, so the orphan sweep must not touch these. Across a
  /// process restart the set is empty, which is exactly what lets the sweep
  /// reclaim a message that was abandoned when the app was killed mid-send.
  final Set<int> inFlightSubmits = {};

  bool isAttached(String runId) => _jobs.containsKey(runId);

  void markSubmitInFlight(int messageId) => inFlightSubmits.add(messageId);

  void clearSubmitInFlight(int messageId) => inFlightSubmits.remove(messageId);

  /// Fail placeholder messages left `PENDING` without a run. This is what
  /// unsticks a chat after the app was closed while the first network call of
  /// a send never completed: otherwise the message would spin forever and the
  /// interrupt button (bound to a run id) would do nothing.
  Future<void> sweepOrphanPlaceholders() async {
    List<LocalMessage> orphans;
    try {
      orphans = await db.pendingWithoutRun();
    } catch (_) {
      return;
    }
    if (orphans.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final message in orphans) {
      if (inFlightSubmits.contains(message.id)) continue;
      try {
        await db.updateMessage(message.copyWith(
          status: MessageStatus.error,
          error: '消息未发出（应用在发送过程中被关闭），请重新发送',
          updatedAt: now,
        ));
        await db.setActiveRun(message.sessionId, null, null);
      } catch (_) {}
    }
  }

  /// Start (or resume) streaming events for a run. Safe to call multiple times.
  void attach(String runId, String sessionId) {
    if (_jobs.containsKey(runId)) return;
    final job = _RunJob();
    _jobs[runId] = job;
    unawaited(_streamWithRetry(runId, sessionId, job));
  }

  /// Stream a run's events, reconnecting with backoff when the connection
  /// drops or the server closes the stream before a terminal event arrived.
  /// Reconnecting rebuilds the state from scratch because the server replays
  /// the full event log on every (re)attach.
  ///
  /// Bounded: after [maxStreamAttempts] consecutive attempts without a
  /// terminal event we mark the run RUNNING and hand recovery to the
  /// reconciliation worker (status poll first, SSE only while it is genuinely
  /// still going) instead of spinning forever.
  Future<void> _streamWithRetry(
      String runId, String sessionId, _RunJob job) async {
    var attempt = 0;
    try {
      while (true) {
        final run = await db.getRun(runId);
        if (run == null) return;
        // Already finalised elsewhere (stop() or a worker reconcile).
        if (run.status.isTerminal) return;
        final assistantMessageId = run.assistantMessageId;
        if (assistantMessageId == null) return;
        final state = StreamState(
          runId: runId,
          sessionId: sessionId,
          assistantMessageId: assistantMessageId,
        );
        try {
          // A controller bridges the source stream so [stop] can cancel it
          // immediately; `await for` keeps event processing strictly ordered.
          final wrapper = StreamController<RunEventDto>();
          final source = eventStream.events(runId);
          job.subscription = source.listen(
            wrapper.add,
            onError: (Object e) {
              if (!wrapper.isClosed) wrapper.addError(e);
            },
            onDone: () => wrapper.close(),
            cancelOnError: false,
          );
          job.cancelSource = () async {
            await job.subscription?.cancel();
            await wrapper.close();
          };
          try {
            await for (final event in wrapper.stream) {
              if (job.cancelled) break;
              await _handleEvent(event, state);
            }
          } finally {
            await job.cancelSource?.call();
            job.cancelSource = null;
            job.subscription = null;
          }
        } catch (_) {
          // Network dropped mid-stream: the run lives on server-side, retry below.
        }
        if (job.cancelled) return;
        if (state.finished) return;
        attempt += 1;
        if (attempt >= maxStreamAttempts) {
          // Give up on inline retries; the run stays RUNNING so reconcileAll()
          // (worker or foreground re-entry) polls its status and recovers the
          // final output.
          await _flush(state, MessageStatus.streaming, null);
          await db.updateRunStatus(
            runId,
            status: RunState.running.name.toUpperCase(),
            output: null,
            error: null,
            lastEvent: 'stream.closed',
            usage: UsageJson.encode(state.usage),
          );
          workScheduler.scheduleOneTimeReconcile();
          return;
        }
        var delay = streamRetryBaseMs << (attempt - 1);
        if (delay > streamRetryMaxMs) delay = streamRetryMaxMs;
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    } finally {
      _jobs.remove(runId);
    }
  }

  Future<void> _handleEvent(RunEventDto event, StreamState state) async {
    switch (event.event) {
      case 'message.delta':
        final delta = event.delta;
        if (delta != null && delta.isNotEmpty) {
          // An interim message ended the previous round; the same round may
          // still have tool calls (added right after the interim). So a *new*
          // round only starts once more text arrives after that interim.
          if (state.interimMarked && state.current.hasContent) {
            state.newSegment();
          }
          state.current.text.write(delta);
          await state.requestFlush(() => _flush(state, MessageStatus.streaming, null));
        }

      case 'message.interim':
        final text = event.text ?? '';
        if (text.trim().isNotEmpty && !event.alreadyStreamed) {
          final cur = state.current;
          final trimmed = text.trim();
          final existing = cur.text.toString().trim();
          // This deployment re-sends the already-delta'd text with
          // already_streamed=false, which shows up as the stream *ending with*
          // exactly that text. Only a suffix match is treated as a re-send.
          if (existing != trimmed && !existing.endsWith(trimmed)) {
            if (existing.isNotEmpty) cur.text.write('\n\n');
            cur.text.write(text);
          }
        }
        state.interimMarked = true;
        await state.requestFlush(() => _flush(state, MessageStatus.streaming, null));

      case 'reasoning.delta':
        final delta = event.delta;
        if (delta != null && delta.isNotEmpty) {
          state.current.reasoning.write(delta);
        }
        final text = event.text;
        if (text != null &&
            text.isNotEmpty &&
            state.current.reasoning.isEmpty) {
          state.current.reasoning.write(text);
        }
        await state.requestFlush(() => _flush(state, MessageStatus.streaming, null));

      case 'reasoning.available':
        // On this deployment `reasoning.available` just echoes the assistant's
        // visible text, so recording it would duplicate the body under
        // "思考过程". The real per-round chain-of-thought is only in the server
        // transcript, which syncFromServer applies when the run completes.
        await state.requestFlush(() => _flush(state, MessageStatus.streaming, null));

      case 'tool.started':
        final name = event.tool ?? event.toolName ?? 'tool';
        // A tool opening right after plain streamed text (no interim) begins a
        // fresh round.
        if (state.current.text.toString().isNotEmpty && !state.interimMarked) {
          state.newSegment();
        }
        state.current.tools.add(ToolEvent(
          id: 'tool-${event.seq ?? _nano()}',
          name: name,
          status: 'started',
          preview: _pretty(event.preview),
          startedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        await _flush(state, MessageStatus.streaming, null);

      case 'tool.completed':
        final name = event.tool ?? event.toolName;
        final completed = ToolEvent(
          id: 'tool-${event.seq ?? _nano()}',
          name: name ?? 'tool',
          status: 'completed',
          result: _pretty(event.preview),
          durationMs: event.duration == null
              ? null
              : (event.duration! * 1000).round(), // server sends seconds
          error: event.error != null,
        );
        state.completeTool(name, completed);
        await _flush(state, MessageStatus.streaming, null);

      case 'subagent.start':
        state.current.tools.add(ToolEvent(
          id: 'subagent-${event.subagentId ?? event.seq ?? _nano()}',
          name: event.title ?? event.subagentId ?? 'subagent',
          status: 'subagent_start',
          preview: event.text,
          startedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        await _flush(state, MessageStatus.streaming, null);

      case 'subagent.complete':
        state.completeSubagent(event.subagentId, event.text);
        await _flush(state, MessageStatus.streaming, null);

      case 'run.completed':
        if (event.usage != null) {
          state.usage = _usageFromDto(event.usage!);
        }
        await _finalize(
            state, RunState.completed, event.output, null, 'run.completed');

      case 'run.failed':
      case 'run.error':
        await _finalize(state, RunState.failed, null,
            _pretty(event.error) != 'null' ? _pretty(event.error) : event.text,
            'run.failed');

      case 'run.interrupted':
        await _finalize(state, RunState.interrupted, null, null, 'run.interrupted');

      case 'run.cancelled':
      case 'run.stopped':
        await _finalize(state, RunState.cancelled, null, null, 'run.cancelled');

      default:
        if (event.event != null && event.event!.isNotEmpty) {
          await db.updateRunStatus(
            state.runId,
            status: RunState.running.name.toUpperCase(),
            output: null,
            error: null,
            lastEvent: event.event,
            usage: UsageJson.encode(state.usage),
          );
        }
    }
  }

  Future<void> _flush(StreamState state, MessageStatus status, String? error) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    state.lastFlush = now;
    final segments = state.snapshot();
    await db.updateProgress(
      state.assistantMessageId,
      content: aggregateContent(segments),
      reasoning: aggregateReasoning(segments),
      status: status.name.toUpperCase(),
      toolEvents: ToolEventListJson.encode(segments.expand((s) => s.tools).toList()),
      segments: SegmentListJson.encode(segments),
      error: error,
      usage: UsageJson.encode(state.usage),
    );
  }

  /// Streamed completion (terminal SSE event).
  Future<void> _finalize(
    StreamState state,
    RunState runState,
    String? output,
    String? error,
    String? lastEvent,
  ) async {
    state.finished = true;
    // NEVER clobber streamed rounds: `run.completed.output` only carries the
    // *final* answer, so replacing the accumulated content with it is what used
    // to wipe every earlier round. Only fall back to `output` when nothing at
    // all was streamed (e.g. a late reconcile).
    if (state.snapshot().every((s) => s.text.trim().isEmpty) &&
        output != null &&
        output.trim().isNotEmpty) {
      state.segments.clear();
      state.segments.add(Seg()..text.write(output));
    }
    await _finalizeRun(
      runId: state.runId,
      sessionId: state.sessionId,
      assistantMessageId: state.assistantMessageId,
      segments: state.snapshot(),
      runState: runState,
      error: error,
      usage: state.usage,
      lastEvent: lastEvent,
      existing: null,
      fallbackContent: null,
    );
  }

  /// Completion discovered by polling (reconcile while the app was away).
  Future<void> _finalizeFromServer(
      LocalRun run, RunStatusDto dto, RunState runState) async {
    final messageId = run.assistantMessageId;
    if (messageId == null) return;
    final existing = await db.getMessage(messageId);
    // Preserve whatever we streamed; only synthesise from `output` when we have
    // nothing.
    var segments = const <MessageSegment>[];
    if (existing != null && existing.segments.any((s) => !s.isEmpty)) {
      segments = existing.segments;
    } else if (dto.output != null && dto.output!.trim().isNotEmpty) {
      segments = [MessageSegment(text: dto.output!)];
    }
    final pretty = _pretty(dto.error);
    final error = pretty != 'null' && pretty.isNotEmpty
        ? pretty
        : (runState == RunState.failed ? '任务失败' : null);
    await _finalizeRun(
      runId: run.runId,
      sessionId: run.sessionId,
      assistantMessageId: messageId,
      segments: segments,
      runState: runState,
      error: error,
      usage: dto.usage != null
          ? _usageFromDto(dto.usage!)
          : existing?.usage,
      lastEvent: dto.lastEvent,
      existing: existing,
      fallbackContent: dto.output,
    );
  }

  /// Shared completion core for the streamed ([_finalize]) and polled
  /// ([_finalizeFromServer]) paths: persist the message + run, release the
  /// session's active run, refresh the preview, notify, and line up the
  /// authoritative server-transcript sync.
  Future<void> _finalizeRun({
    required String runId,
    required String sessionId,
    required int assistantMessageId,
    required List<MessageSegment> segments,
    required RunState runState,
    required String? error,
    required Usage? usage,
    required String? lastEvent,
    required LocalMessage? existing,
    required String? fallbackContent,
  }) async {
    final content = aggregateContent(segments);
    final effectiveContent =
        content.trim().isNotEmpty ? content : (fallbackContent ?? '');
    var finalText = '';
    for (final s in segments.reversed) {
      if (s.text.trim().isNotEmpty) {
        finalText = s.text.trim();
        break;
      }
    }
    if (finalText.isEmpty) finalText = content;
    final messageStatus = switch (runState) {
      RunState.completed => MessageStatus.complete,
      RunState.cancelled || RunState.interrupted => MessageStatus.cancelled,
      _ => MessageStatus.error,
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    final reasoning = aggregateReasoning(segments);
    final existingReasoning =
        reasoning.trim().isNotEmpty ? reasoning : (existing?.reasoning ?? '');
    final allTools = segments.expand((s) => s.tools).toList();
    final effectiveTools = allTools.isNotEmpty
        ? allTools
        : (existing?.toolEvents ?? const <ToolEvent>[]);
    final effectiveUsage = usage ?? existing?.usage;
    await db.updateProgress(
      assistantMessageId,
      content: effectiveContent,
      reasoning: existingReasoning,
      status: messageStatus.name.toUpperCase(),
      toolEvents: ToolEventListJson.encode(effectiveTools),
      segments: SegmentListJson.encode(segments),
      error: error,
      usage: UsageJson.encode(effectiveUsage),
    );
    await db.updateRunStatus(
      runId,
      status: runState.name.toUpperCase(),
      output: effectiveContent,
      error: error,
      lastEvent: lastEvent,
      usage: UsageJson.encode(effectiveUsage),
      updatedAt: now,
    );
    await db.setActiveRun(sessionId, null, null);
    var preview = finalText.length > 120 ? finalText.substring(0, 120) : finalText;
    if (preview.isEmpty) {
      final session = await db.getSession(sessionId);
      preview = session?.preview ?? '';
    }
    await db.touchSession(sessionId, now, preview);
    await _notifyIfNeeded(runId, sessionId, runState, finalText, error);
    // Make the streamed message match the server transcript exactly (real
    // chain-of-thought, identical segment order) so a later manual sync changes
    // nothing.
    if (runState == RunState.completed) {
      var synced = false;
      try {
        synced = await syncFromServer(sessionId);
      } catch (_) {
        synced = false;
      }
      if (!synced) {
        unawaited(Future<void>.delayed(const Duration(milliseconds: syncDeferredDelayMs))
            .then((_) async {
          try {
            await syncFromServer(sessionId);
          } catch (_) {}
        }));
      }
    }
  }

  /// Replace the local cache with the authoritative server transcript, in the
  /// exact shape the streaming path produces. Called right after a run
  /// completes so a manual "同步服务端历史" becomes a no-op, and the real
  /// per-round reasoning replaces the streamed approximation.
  ///
  /// Retries a few times: the session row can lag the `run.completed` event by
  /// a moment. The local snapshot is re-read on every attempt, and re-verified
  /// inside the write transaction, so a send landing mid-sync can never be
  /// wiped by the delete+re-insert.
  Future<bool> syncFromServer(String sessionId) async {
    for (var attempt = 0; attempt < syncAttempts; attempt++) {
      final local = await db.listMessages(sessionId);
      if (local.any((m) =>
          m.status == MessageStatus.streaming ||
          m.status == MessageStatus.pending)) {
        return false;
      }
      SessionMessagesResponse? response;
      try {
        response = await api.sessionMessages(sessionId);
      } catch (_) {
        response = null;
      }
      if (response != null && response.data.isNotEmpty) {
        final entities = HistoryFolder.fold(sessionId, response.data,
            previous: local);
        final last = entities.isEmpty ? null : entities.last;
        // Stale transcript (assistant turn not persisted yet): the last row
        // would still be our own user message. Wait for it rather than wiping
        // the streamed answer.
        final ready = last != null &&
            last.role != MessageRole.user &&
            (last.content.trim().isNotEmpty ||
                last.segments.any((s) => !s.isEmpty));
        if (ready) {
          // One transaction => a single invalidation, so the list never flashes
          // the empty state between the delete and the re-insert.
          // [HistoryFolder] reuses the previous row ids for unchanged
          // messages, keeping list items mounted.
          final applied = await db.transaction(() async {
            final fresh = await db.listMessages(sessionId);
            if (fresh.length != local.length ||
                fresh.any((m) =>
                    m.status == MessageStatus.streaming ||
                    m.status == MessageStatus.pending)) {
              // The conversation changed while we were syncing (e.g. a new
              // send): abort instead of wiping the user's turn.
              return false;
            }
            await db.deleteMessagesForSession(sessionId);
            for (final entity in entities) {
              await db.insertMessage(entity);
            }
            return true;
          });
          if (applied) return true;
        }
      }
      await Future<void>.delayed(
          const Duration(milliseconds: syncRetryDelayMs));
    }
    return false;
  }

  Future<void> _notifyIfNeeded(
    String runId,
    String sessionId,
    RunState runState,
    String content,
    String? error,
  ) async {
    final run = await db.getRun(runId);
    if (run == null) return;
    if (run.notified) return;
    // Claim the slot first (compare-and-set) so a stream finalize racing a
    // worker finalize cannot produce two notifications for the same run.
    if (!await db.markNotified(runId)) return;
    // The user is watching this very session: the live UI already shows the
    // outcome, a system notification would just be noise.
    if (appVisibility.isForeground &&
        chatVisibility.foregroundSessionId == sessionId) {
      return;
    }
    final session = await db.getSession(sessionId);
    final title = session?.title ?? 'Hermes';
    String body;
    switch (runState) {
      case RunState.completed:
        body = content.trim().isNotEmpty ? content : '任务已完成';
        if (body.length > 160) body = body.substring(0, 160);
      case RunState.cancelled:
      case RunState.interrupted:
        body = '任务已中断';
      default:
        body = (error ?? '任务失败');
        if (body.length > 160) body = body.substring(0, 160);
    }
    await notifier.notifyRun(
      sessionId: sessionId,
      title: title,
      message: body,
      success: runState == RunState.completed,
    );
  }

  /// Reconcile every locally-known unfinished run. Called when the app returns
  /// to the foreground and from the periodic background job.
  Future<void> reconcileAll() async {
    // Reclaim abandoned send placeholders first: they have no run to reconcile
    // and would otherwise leave the chat stuck on "running".
    await sweepOrphanPlaceholders();
    if (_reconcileBusy) return;
    _reconcileBusy = true;
    try {
      final active = await db.activeRuns();
      for (final run in active) {
        try {
          final dto = await api.runStatus(run.runId);
          final state = RunState.from(dto.status);
          if (state.isTerminal) {
            await _finalizeFromServer(run, dto, state);
          } else {
            await db.updateRunStatus(
              run.runId,
              status: RunState.running.name.toUpperCase(),
              output: run.output,
              error: run.error,
              lastEvent: dto.lastEvent,
              usage: UsageJson.encode(
                  dto.usage != null ? _usageFromDto(dto.usage!) : run.usage),
            );
            attach(run.runId, run.sessionId);
          }
        } catch (_) {
          // Offline / server error — try again next time.
        }
      }
    } finally {
      _reconcileBusy = false;
    }
  }

  /// Request server-side cancellation of a run. The local rows are only marked
  /// CANCELLED once the server acknowledged the stop — otherwise a failed
  /// request would hide a run that is still executing server-side (and its
  /// result would never be recovered).
  Future<void> stop(String runId) async {
    try {
      await api.stopRun(runId);
    } catch (e) {
      throw StopRunException(e);
    }
    final job = _jobs[runId];
    if (job != null) {
      job.cancelled = true;
      await job.cancelSource?.call();
      _jobs.remove(runId);
    }
    final run = await db.getRun(runId);
    if (run == null) return;
    final existing = run.assistantMessageId == null
        ? null
        : await db.getMessage(run.assistantMessageId!);
    final segments = existing?.segments ?? const <MessageSegment>[];
    final assistantMessageId = run.assistantMessageId;
    if (assistantMessageId == null) {
      await db.setActiveRun(run.sessionId, null, null);
      return;
    }
    final content = aggregateContent(segments);
    final effectiveContent =
        content.trim().isNotEmpty ? content : (existing?.content ?? '');
    final reasoning = aggregateReasoning(segments);
    final effectiveReasoning = reasoning.trim().isNotEmpty
        ? reasoning
        : (existing?.reasoning ?? '');
    final allTools = segments.expand((s) => s.tools).toList();
    final effectiveTools = allTools.isNotEmpty
        ? allTools
        : (existing?.toolEvents ?? const <ToolEvent>[]);
    await db.updateProgress(
      assistantMessageId,
      content: effectiveContent,
      reasoning: effectiveReasoning,
      status: MessageStatus.cancelled.name.toUpperCase(),
      toolEvents: ToolEventListJson.encode(effectiveTools),
      segments: SegmentListJson.encode(segments),
      error: null,
      usage: UsageJson.encode(existing?.usage),
    );
    await db.updateRunStatus(
      runId,
      status: RunState.cancelled.name.toUpperCase(),
      output: existing?.content,
      error: null,
      lastEvent: 'run.cancelled',
      usage: UsageJson.encode(existing?.usage),
    );
    await db.setActiveRun(run.sessionId, null, null);
  }

  /// Send an additional instruction into a running task.
  Future<void> steer(String runId, String text) =>
      api.steerRun(runId, text);

  // ---------------------------------------------------------------- helpers

  static int _nano() => DateTime.now().microsecondsSinceEpoch;

  static String _pretty(Object? element) {
    if (element == null) return 'null';
    if (element is String) return element;
    if (element is num || element is bool) return element.toString();
    try {
      return jsonEncode(element);
    } catch (_) {
      return element.toString();
    }
  }

  static Usage _usageFromDto(UsageDto dto) => Usage(
        inputTokens: dto.inputTokens,
        outputTokens: dto.outputTokens,
        totalTokens: dto.totalTokens,
        cacheReadTokens: dto.cacheReadTokens,
        cacheWriteTokens: dto.cacheWriteTokens,
      );

  static String aggregateContent(List<MessageSegment> segments) => segments
      .map((s) => s.text.trim())
      .where((t) => t.isNotEmpty)
      .join('\n\n');

  static String aggregateReasoning(List<MessageSegment> segments) => segments
      .map((s) => s.reasoning.trim())
      .where((t) => t.isNotEmpty)
      .join('\n\n');

  /// How many times to re-poll the transcript before giving up on the
  /// post-run sync.
  static const syncAttempts = 5;
  static const syncRetryDelayMs = 1500;
  static const syncDeferredDelayMs = 10000;

  /// Inline SSE reconnect attempts before handing the run to the reconcile worker.
  static const maxStreamAttempts = 6;
  static const streamRetryBaseMs = 1000;
  static const streamRetryMaxMs = 30000;
}

class StopRunException implements Exception {
  final Object cause;
  const StopRunException(this.cause);
  @override
  String toString() => cause.toString();
}

class _RunJob {
  bool cancelled = false;
  StreamSubscription<RunEventDto>? subscription;
  Future<void> Function()? cancelSource;
}

/// One in-progress round (思维链 / toolcall / 正文).
class Seg {
  final reasoning = StringBuffer();
  final tools = <ToolEvent>[];
  final text = StringBuffer();

  bool get hasContent =>
      reasoning.isNotEmpty || tools.isNotEmpty || text.isNotEmpty;

  MessageSegment snapshot() => MessageSegment(
        reasoning: reasoning.toString(),
        tools: List.of(tools),
        text: text.toString(),
      );
}

class StreamState {
  final String runId;
  final String sessionId;
  final int assistantMessageId;

  final segments = <Seg>[];
  Usage? usage;
  int lastFlush = 0;
  bool finished = false;

  /// True once a `message.interim` marked the current round's commentary.
  bool interimMarked = false;

  StreamState({
    required this.runId,
    required this.sessionId,
    required this.assistantMessageId,
  });

  Seg get current {
    if (segments.isEmpty) segments.add(Seg());
    return segments.last;
  }

  void newSegment() {
    segments.add(Seg());
    interimMarked = false;
  }

  List<MessageSegment> snapshot() =>
      segments.map((s) => s.snapshot()).where((s) => !s.isEmpty).toList();

  void completeTool(String? name, ToolEvent completed) {
    for (var i = segments.length - 1; i >= 0; i--) {
      final tools = segments[i].tools;
      var idx = -1;
      for (var t = tools.length - 1; t >= 0; t--) {
        if ((tools[t].name == name || name == null) &&
            tools[t].status == 'started') {
          idx = t;
          break;
        }
      }
      if (idx >= 0) {
        tools[idx] = tools[idx].copyWith(
          status: 'completed',
          result: completed.result ?? tools[idx].result,
          durationMs: completed.durationMs ?? tools[idx].durationMs,
          error: completed.error,
        );
        return;
      }
    }
    current.tools.add(completed);
  }

  void completeSubagent(String? subagentId, String? text) {
    for (var i = segments.length - 1; i >= 0; i--) {
      final tools = segments[i].tools;
      var idx = -1;
      for (var t = tools.length - 1; t >= 0; t--) {
        if (tools[t].status == 'subagent_start' &&
            (subagentId == null || tools[t].id.contains(subagentId))) {
          idx = t;
          break;
        }
      }
      if (idx >= 0) {
        tools[idx] = tools[idx].copyWith(
          status: 'subagent_complete',
          result: text ?? tools[idx].result,
        );
        return;
      }
    }
  }

  /// Write-through at most ~8x/second to keep the UI live without hammering
  /// SQLite.
  Future<void> requestFlush(Future<void> Function() flush) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastFlush >= 120) {
      await flush();
    }
  }
}
