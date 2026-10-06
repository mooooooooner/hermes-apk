package com.hermes.client.data.repository

import com.google.gson.Gson
import com.google.gson.JsonElement
import com.hermes.client.data.local.HermesDatabase
import com.hermes.client.data.local.RunEntity
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
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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
 */
@Singleton
class RunManager @Inject constructor(
    private val api: HermesApi,
    private val eventStream: RunEventStream,
    private val db: HermesDatabase,
    private val gson: Gson,
    private val notifier: RunCompletionNotifier,
    private val workScheduler: WorkScheduler,
    @ApplicationScope private val scope: CoroutineScope,
) {
    private val sessionDao get() = db.sessionDao()
    private val messageDao get() = db.messageDao()
    private val runDao get() = db.runDao()

    private val jobs = ConcurrentHashMap<String, Job>()
    private val reconcileMutex = Mutex()

    fun isAttached(runId: String): Boolean = jobs.containsKey(runId)

    /** Start (or resume) streaming events for a run. Safe to call multiple times. */
    fun attach(runId: String, sessionId: String) {
        if (jobs.containsKey(runId)) return
        val job = scope.launch {
            try {
                collect(runId, sessionId)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Network dropped while streaming. The run lives on the server; mark it active and
                // let reconciliation recover it (foreground re-entry or the periodic worker).
                runCatching {
                    runDao.get(runId)?.let {
                        runDao.updateStatus(
                            runId, RunState.RUNNING.name, it.output, it.error,
                            it.lastEvent, gson.toJson(it.usage), System.currentTimeMillis(),
                        )
                    }
                }
            } finally {
                jobs.remove(runId)
            }
        }
        jobs[runId] = job
    }

    private suspend fun collect(runId: String, sessionId: String) {
        val run = runDao.get(runId) ?: return
        val assistantMessageId = run.assistantMessageId ?: return
        val state = StreamState(
            runId = runId,
            sessionId = sessionId,
            assistantMessageId = assistantMessageId,
        )
        // The server replays a run's full event log when a client (re)attaches, so we rebuild the
        // message content from scratch. This also makes re-attaching after process death dupe-free.
        eventStream.events(runId)
            .collect { event ->
                handleEvent(event, state)
            }

        // Stream ended without an explicit terminal event: the run is still going server-side.
        if (!state.finished) {
            flush(state, MessageStatus.STREAMING, null)
            runDao.updateStatus(
                runId, RunState.RUNNING.name, null, null, "stream.closed",
                state.usage?.let { gson.toJson(it) }, System.currentTimeMillis(),
            )
            workScheduler.scheduleOneTimeReconcile()
        }
    }

    private suspend fun handleEvent(event: RunEventDto, state: StreamState) {
        when (event.event) {
            "message.delta" -> {
                event.delta?.let { state.content.append(it) }
                state.requestFlush()
            }

            "message.interim" -> {
                if (!event.alreadyStreamed) {
                    event.text?.let { state.content.append(it) }
                    state.requestFlush()
                }
            }

            "reasoning.available", "reasoning.delta" -> {
                event.text?.let {
                    state.reasoning.clear(); state.reasoning.append(it)
                } ?: event.delta?.let { state.reasoning.append(it) }
                state.requestFlush()
            }

            "tool.started" -> {
                val name = event.tool ?: event.toolName ?: "tool"
                state.tools.add(
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
                val idx = state.tools.indexOfLast { it.name == name && it.status == "started" }
                val updated = if (idx >= 0) {
                    state.tools[idx].copy(
                        status = "completed",
                        result = event.preview?.pretty(),
                        durationMs = event.duration?.times(1000)?.toLong(),
                        error = event.error != null,
                    ).also { state.tools[idx] = it }
                } else {
                    ToolEvent(
                        id = "tool-${event.seq ?: System.nanoTime()}",
                        name = name ?: "tool",
                        status = "completed",
                        result = event.preview?.pretty(),
                        durationMs = event.duration?.times(1000)?.toLong(),
                        error = event.error != null,
                    ).also { state.tools.add(it) }
                }
                flush(state, MessageStatus.STREAMING, null)
            }

            "subagent.start" -> {
                state.tools.add(
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
                val idx = state.tools.indexOfLast {
                    it.status == "subagent_start" &&
                        (event.subagentId == null || it.id.contains(event.subagentId))
                }
                if (idx >= 0) {
                    state.tools[idx] = state.tools[idx].copy(
                        status = "subagent_complete",
                        result = event.text ?: state.tools[idx].result,
                    )
                    flush(state, MessageStatus.STREAMING, null)
                }
            }

            "run.completed" -> {
                event.output?.let { out ->
                    state.content.clear(); state.content.append(out)
                }
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
        messageDao.updateProgress(
            id = state.assistantMessageId,
            content = state.content.toString(),
            reasoning = state.reasoning.toString(),
            status = status.name,
            toolEvents = gson.toJson(state.tools),
            error = error,
            usage = state.usage?.let { gson.toJson(it) },
            updatedAt = now,
        )
    }

    private suspend fun finalize(
        state: StreamState,
        runState: RunState,
        output: String?,
        error: String?,
        lastEvent: String?,
    ) {
        state.finished = true
        if (!output.isNullOrBlank()) {
            state.content.clear()
            state.content.append(output)
        }
        val messageStatus = when (runState) {
            RunState.COMPLETED -> MessageStatus.COMPLETE
            RunState.CANCELLED, RunState.INTERRUPTED -> MessageStatus.CANCELLED
            else -> MessageStatus.ERROR
        }
        flush(state, messageStatus, error)

        runDao.updateStatus(
            runId = state.runId,
            status = runState.name,
            output = state.content.toString(),
            error = error,
            lastEvent = lastEvent,
            usage = state.usage?.let { gson.toJson(it) },
            updatedAt = System.currentTimeMillis(),
        )
        sessionDao.setActiveRun(state.sessionId, null, null)
        sessionDao.touch(
            id = state.sessionId,
            updatedAt = System.currentTimeMillis(),
            preview = state.content.toString().take(120),
        )
        notifyIfNeeded(state.runId, state.sessionId, runState, state.content.toString(), error)
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
            notifyId = runId.hashCode(),
        )
        runDao.markNotified(runId)
    }

    /**
     * Reconcile every locally-known unfinished run. Called when the app returns to the foreground
     * and from the periodic WorkManager job.
     */
    suspend fun reconcileAll() {
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

    private suspend fun finalizeFromServer(
        run: RunEntity,
        dto: RunStatusDto,
        runState: RunState,
    ) {
        val messageId = run.assistantMessageId ?: return
        val existing = messageDao.get(messageId)
        val content = dto.output ?: existing?.content.orEmpty()
        val error = dto.error?.pretty() ?: if (runState == RunState.FAILED) "任务失败" else null
        val usage = dto.usage?.toDomain() ?: existing?.usage
        val messageStatus = when (runState) {
            RunState.COMPLETED -> MessageStatus.COMPLETE
            RunState.CANCELLED, RunState.INTERRUPTED -> MessageStatus.CANCELLED
            else -> MessageStatus.ERROR
        }
        messageDao.updateProgress(
            id = messageId,
            content = content,
            reasoning = existing?.reasoning.orEmpty(),
            status = messageStatus.name,
            toolEvents = gson.toJson(existing?.toolEvents ?: emptyList<ToolEvent>()),
            error = error,
            usage = usage?.let { gson.toJson(it) },
            updatedAt = System.currentTimeMillis(),
        )
        runDao.updateStatus(
            runId = run.runId,
            status = runState.name,
            output = content,
            error = error,
            lastEvent = dto.lastEvent,
            usage = usage?.let { gson.toJson(it) },
            updatedAt = System.currentTimeMillis(),
        )
        sessionDao.setActiveRun(run.sessionId, null, null)
        sessionDao.touch(run.sessionId, System.currentTimeMillis(), content.take(120))
        notifyIfNeeded(run.runId, run.sessionId, runState, content, error)
    }

    /** Request server-side cancellation of a run. */
    suspend fun stop(runId: String) {
        runCatching { api.stopRun(runId) }
        jobs[runId]?.cancel()
        jobs.remove(runId)
        val run = runDao.get(runId) ?: return
        val existing = run.assistantMessageId?.let { messageDao.get(it) }
        messageDao.updateProgress(
            id = run.assistantMessageId ?: return,
            content = existing?.content.orEmpty(),
            reasoning = existing?.reasoning.orEmpty(),
            status = MessageStatus.CANCELLED.name,
            toolEvents = gson.toJson(existing?.toolEvents ?: emptyList<ToolEvent>()),
            error = null,
            usage = existing?.usage?.let { gson.toJson(it) },
            updatedAt = System.currentTimeMillis(),
        )
        runDao.updateStatus(
            runId, RunState.CANCELLED.name, existing?.content, null, "run.cancelled",
            existing?.usage?.let { gson.toJson(it) }, System.currentTimeMillis(),
        )
        sessionDao.setActiveRun(run.sessionId, null, null)
    }

    /** Send an additional instruction into a running task. */
    suspend fun steer(runId: String, text: String): Result<Unit> = runCatching {
        api.steerRun(runId, com.hermes.client.data.remote.dto.SteerRequest(input = text))
    }

    private fun JsonElement.pretty(): String = runCatching {
        if (isJsonPrimitive) asString else gson.toJson(this)
    }.getOrDefault(toString())

    private inner class StreamState(
        val runId: String,
        val sessionId: String,
        val assistantMessageId: Long,
    ) {
        val content = StringBuilder()
        val reasoning = StringBuilder()
        val tools = mutableListOf<ToolEvent>()
        var usage: Usage? = null
        var lastFlush: Long = 0
        var finished: Boolean = false

        /** Write-through at most ~8x/second to keep the UI live without hammering SQLite. */
        suspend fun requestFlush() {
            val now = System.currentTimeMillis()
            if (now - lastFlush >= 120) {
                flush(this, MessageStatus.STREAMING, null)
            }
        }
    }
}
