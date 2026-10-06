package com.hermes.client.data.remote.sse

import com.google.gson.Gson
import com.hermes.client.data.remote.dto.RunEventDto
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.di.SseClient
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import okhttp3.sse.EventSources
import java.io.IOException
import javax.inject.Inject

/**
 * Live event stream for an async run (`GET /v1/runs/{id}/events`).
 *
 * Uses the official okhttp-sse EventSource so that `: keepalive` comment lines are ignored and
 * a dropped connection is surfaced as [EventSourceListener.onFailure] instead of a silent hang.
 */
class RunEventStream @Inject constructor(
    @SseClient private val client: OkHttpClient,
    private val gson: Gson,
    private val settings: SettingsRepository,
) {

    fun events(runId: String): Flow<RunEventDto> = callbackFlow {
        if (settings.cachedBaseUrl.isBlank()) {
            close(IOException("尚未配置服务器地址"))
            awaitClose { }
            return@callbackFlow
        }
        // Build only the RELATIVE path (placeholder host). If we used the configured Base URL here
        // the DynamicUrlInterceptor would prepend its path a second time (e.g. /hermes-api/hermes-api/…).
        val request = Request.Builder()
            .url("http://localhost/v1/runs/$runId/events")
            .header("Accept", "text/event-stream")
            .header("Cache-Control", "no-cache")
            .build()

        val listener = object : EventSourceListener() {
            override fun onEvent(eventSource: EventSource, id: String?, type: String?, data: String) {
                if (data.isBlank()) return
                runCatching { gson.fromJson(data, RunEventDto::class.java) }
                    .getOrNull()
                    ?.let { trySend(it) }
            }

            override fun onClosed(eventSource: EventSource) {
                close()
            }

            override fun onFailure(eventSource: EventSource, t: Throwable?, response: Response?) {
                close(t ?: IOException("事件流断开 (HTTP ${response?.code})"))
            }
        }

        val eventSource = EventSources.createFactory(client).newEventSource(request, listener)
        awaitClose { eventSource.cancel() }
    }
}
