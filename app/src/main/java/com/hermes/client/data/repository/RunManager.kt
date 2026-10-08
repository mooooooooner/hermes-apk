package com.hermes.client.data.repository

import androidx.room.withTransaction
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.hermes.client.AppVisibility
import com.hermes.client.ChatVisibility
import com.hermes.client.data.local.HermesDatabase
import com.hermes.client.data.local.MessageEntity
import com.hermes.client.data.local.RunEntity
import com.hermes.client.data.model.MessageSegment
import com.hermes.client.data.model.MessageRole
import com.hermes.client.data.model.MessageStatus
import com.hermes.client.data.model.RunState
import com.hermes.client.data.model.ToolEvent
import com.hermes.client.data.model.Usage
import com.hermes.client.data.remote.HermesApi
import com.hermes.client.data.remote.dto.RunEventDto
import com.hermes.client.data.remote.dto.RunStatusDto
import com.hermes.client.data.remote.sse.RunEventStream
import com.hermes.client.di.ApplicationScope
import com.hermes.client.notifications.RunCompletionNotifier
import com.hermes.client.worker.WorkScheduler
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Owns the lifecycle of async Hermes runs. This is the heart of the "close the app and come back"
 * guarantee:
 *
 *  1. a run is persisted before we start streaming;
 *  2. every event is written through to Room so the UI can render it (or restore it) at any time;
 *  3. if the process dies the server keeps working — [reconcileAll] re-attaches or finalises runs
 *     when the app comes back.
 *
 * Hermes runs an agent loop, so one run can contain several rounds of
 * `思维链 -> toolcall -> 正文`. The stream is folded into an ordered list of [MessageSegment]s
 * (see [StreamState]) instead of a single flat reasoning/tool/text blob, which keeps the timeline
 * faithful during streaming *and* after a server-history sync.
 */
@Singleton
class RunManager @Inject constructor(
    private val api: HermesApi,
    private val eventStream: RunEventStream,
    private val db: HermesDatabase,
    private val gson: Gson,
    private val notifier: RunCompletionNotifier,
    private val workScheduler: WorkScheduler,
    private val appVisibility: AppVisibility,
    private val chatVisibility: ChatVisibility,
    @ApplicationScope private val scope: CoroutineScope,
) {
    private val sessionDao get() = db.sessionDao()
    private val messageDao get() = db.messageDao()
    private val runDao get() = db.runDao()

    private val jobs = ConcurrentHashMap<String, Job>()
    private val reconcileMutex = Mutex()

    /**
     * Placeholder message ids for which a `POST /v1/runs` is currently in flight. A placeholder
     * exists as `PENDING` with `runId == null` for the whole submit window, so the orphan sweep
     * must not touch these. Across a process restart the set is empty, which is exactly what lets
     * the sweep reclaim a message that was abandoned when the app was killed mid-send.
     */
    private val inFlightSubmits: MutableSet<Long> = ConcurrentHashMap.newKeySet()

    fun isAttached(runId: String): Boolean = jobs.containsKey(runId)

    fun markSubmitInFlight(messageId: Long) {
        inFlightSubmits.add(messageId)
    }

    fun clearSubmitInFlight(messageId: Long) {
        inFlightSubmits.remove(messageId)
    }

    /**
     * Fail placeholder messages left `PENDING` without a run. This is what unsticks a chat after
     * the app was closed while the first network call of a send never completed: otherwise the
     * message would spin forever and the interrupt button (bound to a run id) would do nothing.
     */
    suspend fun sweepOrphanPlaceholders() {
        val orphans = runCatching { messageDao.pendingWithoutRun() }.getOrNull() ?: return
        if (orphans.isEmpty()) return
        val now = System.currentTimeMillis()
        orphans.forEach { message ->
            if (message.id in inFlightSubmits) return@forEach
            runCatching {
                messageDao.update(
                    message.copy(
                        status = MessageStatus.ERROR.name,
                        error = "消息未发出（应用在发送过程中被关闭），请重新发送",
                        updatedAt = now,
                    ),
                )
                sessionDao.setActiveRun(message.sessionId, null, null)
            }
        }
    }

    /**
     * Start (or resume) streaming events for a run. Safe to call multiple times.
     *
     * The job registers itself in [jobs] atomically (putIfAbsent) and unregisters via
     * [Job.invokeOnCompletion], so neither a fast-completing stream nor two concurrent attaches
     * can leave a stale entry that would block future re-attachment.
     */
    fun attach(runId: String, sessionId: String) {
        if (jobs.containsKey(runId)) return
        val job = scope.launch { streamWithRetry(runId, sessionId) }
        if (jobs.putIfAbsent(runId, job) != null) {
            // Another attach won the race; drop our duplicate.
            job.cancel()
            return
        }
        job.invokeOnCompletion { jobs.remove(runId, job) }
    }

    /**
     * Stream a run's events, reconnecting with backoff when the connection drops or the server
     * closes the stream before a terminal event arrived. Reconnecting rebuilds the state from
     * scratch because the server replays the full event log on every (re)attach.
     *
     * Bounded: after [MAX_STREAM_ATTEMPTS] consecutive attempts without a terminal event we mark
     * the run RUNNING and hand recovery to the reconciliation worker (status poll first, SSE
     * only while it is genuinely still going) instead of spinning forever.
     */
    private suspend fun streamWithRetry(runId: String, sessionId: String) {
        var attempt = 0
        while (true) {
            val run = runDao.get(runId) ?: return
            // Already finalised elsewhere (stop() or a worker reconcile) — nothing to stream.
            if (RunState.from(run.status).isTerminal) return
            val assistantMessageId = run.assistantMessageId ?: return
            val state = StreamState(
                runId = runId,
                sessionId = sessionId,
                assistantMessageId = assistantMessageId,
            )
            try {
                eventStream.events(runId)
                    .collect { event -> handleEvent(event, state) }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Network dropped mid-stream: the run lives on server-side, retry below.
            }
            if (state.finished) return
            attempt += 1
            if (attempt >= MAX_STREAM_ATTEMPTS) {
                // Give up on inline retries; the run stays RUNNING so reconcileAll() (worker or
                // foreground re-entry) polls its status and recovers the final output.
                flush(state, MessageStatus.STREAMING, null)
                runDao.updateStatus(
                    runId, RunState.RUNNING.name, null, null, "stream.closed",
                    state.usage?.let { gson.toJson(it) }, System.currentTimeMillis(),
                )
                workScheduler.scheduleOneTimeReconcile()
                return
            }
            delay(minOf(STREAM_RETRY_BASE_MS shl (attempt - 1), STREAM_RETRY_MAX_MS))
        }
    }

    private suspend fun handleEvent(event: RunEventDto, state: StreamState) {
        when (event.event) {
            "message.delta" -> {
                val delta = event.delta
                if (!delta.isNullOrEmpty()) {
                    // An interim message ended the previous round; the same round may still have
                    // tool calls (added right after the interim). So a *new* round only starts once
                    // more text arrives after that interim.
                    if (state.interimMarked && state.current().hasContent()) state.newSegment()
                    state.current().text.append(delta)
                    state.requestFlush()
                }
            }

            "message.interim" -> {
                val text = event.text.orEmpty()
                if (text.isNotBlank() && !event.alreadyStreamed) {
                    val cur = state.current()
                    val trimmed = text.trim()
                    val existing = cur.text.toString().trim()
                    // This deployment re-sends the already-delta'd text with already_streamed=false,
                    // which shows up as the stream *ending with* exactly that text. Only a suffix
                    // match is treated as a re-send: a `contains` check would also swallow
                    // genuinely new commentary whose phrasing appeared earlier in the round.
                    if (existing != trimmed && !existing.endsWith(trimmed)) {
                        if (existing.isNotEmpty()) cur.text.append("\n\n")
                        cur.text.append(text)
                    }
                }
                state.interimMarked = true
                state.requestFlush()
            }

            "reasoning.delta" -> {
                event.delta?.let { state.current().reasoning.append(it) }
                event.text?.let { if (state.current().reasoning.isEmpty()) state.current().reasoning.append(it) }
                state.requestFlush()
            }

            "reasoning.available" -> {
                // On this deployment `reasoning.available` just echoes the assistant's visible text
                // (the server relays `assistant_message.content`), so recording it would duplicate
                // the body under "思考过程". The real per-round chain-of-thought is only in the
                // server transcript, which [syncFromServer] applies when the run completes.
                state.requestFlush()
            }

            "tool.started" -> {
                val name = event.tool ?: event.toolName ?: "tool"
                // A tool opening right after plain streamed text (no interim) begins a fresh round.
                if (state.current().text.isNotBlank() && !state.interimMarked) state.newSegment()
                state.current().tools.add(
                    ToolEvent(
                        id = "tool-${event.seq ?: System.nanoTime()}",
                        name = name,
                        status = "started",
                        preview = event.preview?.pretty(),
                        startedAt = System.currentTimeMillis(),
                    ),
                )
                flush(state, MessageStatus.STREAMING, null)
            }

            "tool.completed" -> {
                val name = event.tool ?: event.toolName
                val completed = ToolEvent(
                    id = "tool-${event.seq ?: System.nanoTime()}",
                    name = name ?: "tool",
                    status = "completed",
                    result = event.preview?.pretty(),
                    durationMs = event.duration?.times(1000)?.toLong(), // server sends seconds
                    error = event.error != null,
                )
                state.completeTool(name, completed)
                flush(state, MessageStatus.STREAMING, null)
            }

            "subagent.start" -> {
                state.current().tools.add(
                    ToolEvent(
                        id = "subagent-${event.subagentId ?: event.seq ?: System.nanoTime()}",
                        name = event.title ?: event.subagentId ?: "subagent",
                        status = "subagent_start",
                        preview = event.text,
                        startedAt = System.currentTimeMillis(),
                    ),
                )
                flush(state, MessageStatus.STREAMING, null)
            }

            "subagent.complete" -> {
                state.completeSubagent(event.subagentId, event.text)
                flush(state, MessageStatus.STREAMING, null)
            }

            "run.completed" -> {
                event.usage?.let { state.usage = it.toDomain() }
                finalize(state, RunState.COMPLETED, event.output, null, "run.completed")
            }

            "run.failed", "run.error" -> {
                finalize(state, RunState.FAILED, null, event.error?.pretty() ?: event.text, "run.failed")
            }

            "run.interrupted" -> finalize(state, RunState.INTERRUPTED, null, null, "run.interrupted")

            "run.cancelled", "run.stopped" -> finalize(state, RunState.CANCELLED, null, null, "run.cancelled")

            else -> {
                if (!event.event.isNullOrBlank()) {
                    runDao.updateStatus(
                        state.runId, RunState.RUNNING.name, null, null, event.event,
                        state.usage?.let { gson.toJson(it) }, System.currentTimeMillis(),
                    )
                }
            }
        }
    }

    private suspend fun flush(state: StreamState, status: MessageStatus, error: String?) {
        val now = System.currentTimeMillis()
        state.lastFlush = now
        val segments = state.snapshot()
        messageDao.updateProgress(
            id = state.assistantMessageId,
            content = aggregateContent(segments),
            reasoning = aggregateReasoning(segments),
            status = status.name,
            toolEvents = gson.toJson(segments.flatMap { it.tools }),
            segments = gson.toJson(segments),
            error = error,
            usage = state.usage?.let { gson.toJson(it) },
            updatedAt = now,
        )
    }

    /** Streamed completion (terminal SSE event). */
    private suspend fun finalize(
        state: StreamState,
        runState: RunState,
        output: String?,
        error: String?,
        lastEvent: String?,
    ) {
        state.finished = true
        // NEVER clobber streamed rounds: `run.completed.output` only carries the *final* answer, so
        // replacing the accumulated content with it is what used to wipe every earlier round. Only
        // fall back to `output` when nothing at all was streamed (e.g. a late reconcile).
        if (state.snapshot().none { it.text.isNotBlank() } && !output.isNullOrBlank()) {
            state.segments.clear()
            state.segments.add(Seg().apply { text.append(output) })
        }
        finalizeRun(
            runId = state.runId,
            sessionId = state.sessionId,
            assistantMessageId = state.assistantMessageId,
            segments = state.snapshot(),
            runState = runState,
            error = error,
            usage = state.usage,
            lastEvent = lastEvent,
            existing = null,
            fallbackContent = null,
        )
    }

    /** Completion discovered by polling (reconcile while the app was away). */
    private suspend fun finalizeFromServer(
        run: RunEntity,
        dto: RunStatusDto,
        runState: RunState,
    ) {
        val messageId = run.assistantMessageId ?: return
        val existing = messageDao.get(messageId)
        // Preserve whatever we streamed; only synthesise from `output` when we have nothing.
        val segments = existing?.segments.orEmpty().takeIf { segs -> segs.any { !it.isEmpty } }
            ?: dto.output?.takeIf { it.isNotBlank() }?.let { listOf(MessageSegment(text = it)) }
            ?: emptyList()
        val error = dto.error?.pretty() ?: if (runState == RunState.FAILED) "任务失败" else null
        finalizeRun(
            runId = run.runId,
            sessionId = run.sessionId,
            assistantMessageId = messageId,
            segments = segments,
            runState = runState,
            error = error,
            usage = dto.usage?.toDomain() ?: existing?.usage,
            lastEvent = dto.lastEvent,
            existing = existing,
            fallbackContent = dto.output,
        )
    }

    /**
     * Shared completion core for the streamed ([finalize]) and polled ([finalizeFromServer])
     * paths: persist the message + run, release the session's active run, refresh the preview,
     * notify, and line up the authoritative server-transcript sync.
     */
    private suspend fun finalizeRun(
        runId: String,
        sessionId: String,
        assistantMessageId: Long,
        segments: List<MessageSegment>,
        runState: RunState,
        error: String?,
        usage: Usage?,
        lastEvent: String?,
        existing: MessageEntity?,
        fallbackContent: String?,
    ) {
        val content = aggregateContent(segments).ifBlank { fallbackContent.orEmpty() }
        val finalText = segments.lastOrNull { it.text.isNotBlank() }?.text?.trim().orEmpty()
            .ifBlank { content }
        val messageStatus = when (runState) {
            RunState.COMPLETED -> MessageStatus.COMPLETE
            RunState.CANCELLED, RunState.INTERRUPTED -> MessageStatus.CANCELLED
            else -> MessageStatus.ERROR
        }
        messageDao.updateProgress(
            id = assistantMessageId,
            content = content,
            reasoning = aggregateReasoning(segments).ifBlank { existing?.reasoning.orEmpty() },
            status = messageStatus.name,
            toolEvents = gson.toJson(
                segments.flatMap { it.tools }.ifEmpty { existing?.toolEvents ?: emptyList() },
            ),
            segments = gson.toJson(segments),
            error = error,
            usage = (usage ?: existing?.usage)?.let { gson.toJson(it) },
            updatedAt = System.currentTimeMillis(),
        )
        runDao.updateStatus(
            runId = runId,
            status = runState.name,
            output = content,
            error = error,
            lastEvent = lastEvent,
            usage = usage?.let { gson.toJson(it) } ?: existing?.usage?.let { gson.toJson(it) },
            updatedAt = System.currentTimeMillis(),
        )
        sessionDao.setActiveRun(sessionId, null, null)
        sessionDao.touch(
            id = sessionId,
            updatedAt = System.currentTimeMillis(),
            preview = finalText.take(120).ifBlank { sessionDao.get(sessionId)?.preview ?: "" },
        )
        notifyIfNeeded(runId, sessionId, runState, finalText, error)
        // Make the streamed message match the server transcript exactly (real chain-of-thought,
        // identical segment order) so a later manual sync changes nothing.
        if (runState == RunState.COMPLETED) {
            val synced = runCatching { syncFromServer(sessionId) }.getOrDefault(false)
            if (!synced) {
                scope.launch {
                    delay(SYNC_DEFERRED_DELAY_MS)
                    runCatching { syncFromServer(sessionId) }
                }
            }
        }
    }

    /**
     * Replace the local cache with the authoritative server transcript, in the exact shape the
     * streaming path produces. Called right after a run completes so a manual "同步服务端历史"
     * becomes a no-op, and the real per-round reasoning replaces the streamed approximation.
     *
     * Retries a few times: the session row can lag the `run.completed` event by a moment.
     * The local snapshot is re-read on every attempt, and re-verified inside the write
     * transaction, so a send landing mid-sync can never be wiped by the delete+re-insert.
     */
    suspend fun syncFromServer(sessionId: String): Boolean {
        repeat(SYNC_ATTEMPTS) {
            val local = messageDao.list(sessionId)
            if (local.any {
                    it.status == MessageStatus.STREAMING.name || it.status == MessageStatus.PENDING.name
                }
            ) {
                return false
            }
            val response = runCatching { api.sessionMessages(sessionId) }.getOrNull()
            if (response != null && response.data.isNotEmpty()) {
                val entities = HistoryFolder.fold(sessionId, response.data, local)
                val last = entities.lastOrNull()
                // Stale transcript (assistant turn not persisted yet): the last row would still be
                // our own user message. Wait for it rather than wiping the streamed answer.
                val ready = last != null && last.role != MessageRole.USER.name &&
                    (last.content.isNotBlank() || last.segments.any { !it.isEmpty })
                if (ready) {
                    // One transaction => a single Room invalidation, so the list never flashes the
                    // empty state between the delete and the re-insert. [HistoryFolder] reuses the
                    // previous row ids for unchanged messages, keeping LazyColumn items mounted.
                    val applied = db.withTransaction {
                        val fresh = messageDao.list(sessionId)
                        if (fresh.size != local.size || fresh.any {
                                it.status == MessageStatus.STREAMING.name ||
                                    it.status == MessageStatus.PENDING.name
                            }
                        ) {
                            // The conversation changed while we were syncing (e.g. a new send):
                            // abort instead of wiping the user's turn.
                            false
                        } else {
                            messageDao.deleteForSession(sessionId)
                            entities.forEach { messageDao.insert(it) }
                            true
                        }
                    }
                    if (applied) return true
                }
            }
            delay(SYNC_RETRY_DELAY_MS)
        }
        return false
    }

    private suspend fun notifyIfNeeded(
        runId: String,
        sessionId: String,
        runState: RunState,
        content: String,
        error: String?,
    ) {
        val run = runDao.get(runId) ?: return
        if (run.notified) return
        // Claim the slot first (compare-and-set) so a stream finalize racing a worker finalize
        // cannot produce two notifications for the same run.
        if (runDao.markNotified(runId) == 0) return
        // The user is watching this very session: the live UI already shows the outcome, a system
        // notification would just be noise.
        if (appVisibility.isForeground && chatVisibility.foregroundSessionId == sessionId) return
        val session = sessionDao.get(sessionId)
        val title = session?.title ?: "Hermes"
        val body = when (runState) {
            RunState.COMPLETED -> content.ifBlank { "任务已完成" }.take(160)
            RunState.CANCELLED, RunState.INTERRUPTED -> "任务已中断"
            else -> (error ?: "任务失败").take(160)
        }
        notifier.notifyRun(
            sessionId = sessionId,
            title = title,
            message = body,
            success = runState == RunState.COMPLETED,
        )
    }

    /**
     * Reconcile every locally-known unfinished run. Called when the app returns to the foreground
     * and from the periodic WorkManager job.
     */
    suspend fun reconcileAll() {
        // Reclaim abandoned send placeholders first: they have no run to reconcile and would
        // otherwise leave the chat stuck on "running".
        sweepOrphanPlaceholders()
        if (!reconcileMutex.tryLock()) return
        try {
            val active = runDao.activeRuns()
            for (run in active) {
                try {
                    val dto = api.runStatus(run.runId)
                    val state = RunState.from(dto.status)
                    if (state.isTerminal) {
                        finalizeFromServer(run, dto, state)
                    } else {
                        runDao.updateStatus(
                            run.runId, RunState.RUNNING.name, run.output, run.error,
                            dto.lastEvent, gson.toJson(dto.usage?.toDomain() ?: run.usage),
                            System.currentTimeMillis(),
                        )
                        attach(run.runId, run.sessionId)
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (_: Exception) {
                    // Offline / server error — try again next time.
                }
            }
        } finally {
            reconcileMutex.unlock()
        }
    }

    /**
     * Request server-side cancellation of a run. The local rows are only marked CANCELLED once
     * the server acknowledged the stop — otherwise a failed request would hide a run that is
     * still executing server-side (and its result would never be recovered).
     */
    suspend fun stop(runId: String): Result<Unit> {
        val failure = runCatching { api.stopRun(runId) }.exceptionOrNull()
        if (failure != null) return Result.failure(failure)
        val job = jobs[runId]
        job?.cancel()
        if (job != null) jobs.remove(runId, job)
        val run = runDao.get(runId) ?: return Result.success(Unit)
        val existing = run.assistantMessageId?.let { messageDao.get(it) }
        val segments = existing?.segments.orEmpty()
        messageDao.updateProgress(
            id = run.assistantMessageId ?: return Result.success(Unit),
            content = aggregateContent(segments).ifBlank { existing?.content.orEmpty() },
            reasoning = aggregateReasoning(segments).ifBlank { existing?.reasoning.orEmpty() },
            status = MessageStatus.CANCELLED.name,
            toolEvents = gson.toJson(
                segments.flatMap { it.tools }.ifEmpty { existing?.toolEvents ?: emptyList() },
            ),
            segments = gson.toJson(segments),
            error = null,
            usage = existing?.usage?.let { gson.toJson(it) },
            updatedAt = System.currentTimeMillis(),
        )
        runDao.updateStatus(
            runId, RunState.CANCELLED.name, existing?.content, null, "run.cancelled",
            existing?.usage?.let { gson.toJson(it) }, System.currentTimeMillis(),
        )
        sessionDao.setActiveRun(run.sessionId, null, null)
        return Result.success(Unit)
    }

    /** Send an additional instruction into a running task. */
    suspend fun steer(runId: String, text: String): Result<Unit> = runCatching {
        api.steerRun(runId, com.hermes.client.data.remote.dto.SteerRequest(input = text))
    }

    private fun JsonElement.pretty(): String = runCatching {
        if (isJsonPrimitive) asString else gson.toJson(this)
    }.getOrDefault(toString())

    private fun aggregateContent(segments: List<MessageSegment>): String =
        segments.map { it.text.trim() }.filter { it.isNotEmpty() }.joinToString("\n\n")

    private fun aggregateReasoning(segments: List<MessageSegment>): String =
        segments.map { it.reasoning.trim() }.filter { it.isNotEmpty() }.joinToString("\n\n")

    /** One in-progress round (思维链 / toolcall / 正文). */
    private inner class Seg {
        val reasoning = StringBuilder()
        val tools = mutableListOf<ToolEvent>()
        val text = StringBuilder()

        fun hasContent(): Boolean =
            reasoning.isNotEmpty() || tools.isNotEmpty() || text.isNotEmpty()

        fun snapshot(): MessageSegment =
            MessageSegment(reasoning.toString(), tools.toList(), text.toString())
    }

    private inner class StreamState(
        val runId: String,
        val sessionId: String,
        val assistantMessageId: Long,
    ) {
        val segments = mutableListOf<Seg>()
        var usage: Usage? = null
        var lastFlush: Long = 0
        var finished: Boolean = false

        /** True once a `message.interim` marked the current round's commentary. */
        var interimMarked: Boolean = false

        fun current(): Seg {
            if (segments.isEmpty()) segments.add(Seg())
            return segments.last()
        }

        fun newSegment() {
            segments.add(Seg())
            interimMarked = false
        }

        fun snapshot(): List<MessageSegment> =
            segments.map { it.snapshot() }
                .filterNot { it.isEmpty }
                .ifEmpty { emptyList() }

        fun completeTool(name: String?, completed: ToolEvent) {
            for (i in segments.indices.reversed()) {
                val tools = segments[i].tools
                val idx = tools.indexOfLast { (it.name == name || name == null) && it.status == "started" }
                if (idx >= 0) {
                    tools[idx] = tools[idx].copy(
                        status = "completed",
                        result = completed.result ?: tools[idx].result,
                        durationMs = completed.durationMs ?: tools[idx].durationMs,
                        error = completed.error,
                    )
                    return
                }
            }
            current().tools.add(completed)
        }

        fun completeSubagent(subagentId: String?, text: String?) {
            for (i in segments.indices.reversed()) {
                val tools = segments[i].tools
                val idx = tools.indexOfLast {
                    it.status == "subagent_start" &&
                        (subagentId == null || it.id.contains(subagentId))
                }
                if (idx >= 0) {
                    tools[idx] = tools[idx].copy(
                        status = "subagent_complete",
                        result = text ?: tools[idx].result,
                    )
                    return
                }
            }
        }

        /** Write-through at most ~8x/second to keep the UI live without hammering SQLite. */
        suspend fun requestFlush() {
            val now = System.currentTimeMillis()
            if (now - lastFlush >= 120) {
                flush(this, MessageStatus.STREAMING, null)
            }
        }
    }

    private companion object {
        /** How many times to re-poll the transcript before giving up on the post-run sync. */
        const val SYNC_ATTEMPTS = 5
        const val SYNC_RETRY_DELAY_MS = 1500L
        const val SYNC_DEFERRED_DELAY_MS = 10_000L

        /** Inline SSE reconnect attempts before handing the run to the reconcile worker. */
        const val MAX_STREAM_ATTEMPTS = 6
        const val STREAM_RETRY_BASE_MS = 1_000L
        const val STREAM_RETRY_MAX_MS = 30_000L
    }
}
