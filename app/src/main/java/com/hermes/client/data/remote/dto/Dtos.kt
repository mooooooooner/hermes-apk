package com.hermes.client.data.remote.dto

import com.google.gson.JsonElement
import com.google.gson.annotations.SerializedName

/** GET /v1/models */
data class ModelsResponse(
    @SerializedName("object") val objectType: String? = null,
    @SerializedName("data") val data: List<ModelInfo> = emptyList(),
)

data class ModelInfo(
    @SerializedName("id") val id: String? = null,
    @SerializedName("object") val objectType: String? = null,
    @SerializedName("owned_by") val ownedBy: String? = null,
    @SerializedName("created") val created: Long? = null,
)

/** GET /health */
data class HealthResponse(
    @SerializedName("status") val status: String? = null,
    @SerializedName("platform") val platform: String? = null,
    @SerializedName("version") val version: String? = null,
)

/** GET /v1/capabilities (unknown fields are ignored by Gson) */
data class Capabilities(
    @SerializedName("object") val objectType: String? = null,
    @SerializedName("platform") val platform: String? = null,
    @SerializedName("model") val model: String? = null,
    @SerializedName("features") val features: CapabilityFeatures? = null,
)

data class CapabilityFeatures(
    @SerializedName("chat_completions") val chatCompletions: Boolean? = null,
    @SerializedName("chat_completions_streaming") val chatCompletionsStreaming: Boolean? = null,
    @SerializedName("run_submission") val runSubmission: Boolean? = null,
    @SerializedName("run_status") val runStatus: Boolean? = null,
    @SerializedName("run_events_sse") val runEventsSse: Boolean? = null,
    @SerializedName("run_stop") val runStop: Boolean? = null,
    @SerializedName("run_steer") val runSteer: Boolean? = null,
    @SerializedName("tool_progress_events") val toolProgressEvents: Boolean? = null,
    @SerializedName("reasoning_streaming") val reasoningStreaming: Boolean? = null,
    @SerializedName("session_resources") val sessionResources: Boolean? = null,
    @SerializedName("session_chat") val sessionChat: Boolean? = null,
    @SerializedName("runs_idempotency") val runsIdempotency: IdempotencySupport? = null,
)

data class IdempotencySupport(
    @SerializedName("supported") val supported: Boolean? = null,
    @SerializedName("durable") val durable: Boolean? = null,
)

/** POST /v1/runs */
data class RunRequest(
    @SerializedName("input") val input: JsonElement,
    @SerializedName("session_id") val sessionId: String? = null,
    @SerializedName("instructions") val instructions: String? = null,
    @SerializedName("conversation_history") val conversationHistory: List<HistoryMessage>? = null,
)

data class HistoryMessage(
    @SerializedName("role") val role: String,
    @SerializedName("content") val content: String,
)

/** One OpenAI-style content part for multimodal input (`{"type":"text"|, "text":...}`). */
data class InputTextPart(
    @SerializedName("type") val type: String = "text",
    @SerializedName("text") val text: String,
)

data class ImageUrl(
    @SerializedName("url") val url: String,
    @SerializedName("detail") val detail: String? = null,
)

data class InputImagePart(
    @SerializedName("type") val type: String = "image_url",
    @SerializedName("image_url") val imageUrl: ImageUrl,
)

/** A single user turn whose `content` may be a list of text/image parts. */
data class InputUserMessage(
    @SerializedName("role") val role: String = "user",
    @SerializedName("content") val content: JsonElement,
)

data class RunCreatedDto(
    @SerializedName("run_id") val runId: String,
    @SerializedName("status") val status: String? = null,
    @SerializedName("replayed") val replayed: Boolean = false,
)

/** GET /v1/runs/{id} */
data class RunStatusDto(
    @SerializedName("object") val objectType: String? = null,
    @SerializedName("run_id") val runId: String? = null,
    @SerializedName("status") val status: String? = null,
    @SerializedName("session_id") val sessionId: String? = null,
    @SerializedName("model") val model: String? = null,
    @SerializedName("output") val output: String? = null,
    @SerializedName("usage") val usage: UsageDto? = null,
    @SerializedName("runtime") val runtime: RuntimeDto? = null,
    @SerializedName("created_at") val createdAt: Double? = null,
    @SerializedName("updated_at") val updatedAt: Double? = null,
    @SerializedName("last_event") val lastEvent: String? = null,
    @SerializedName("completed") val completed: Boolean = false,
    @SerializedName("partial") val partial: Boolean = false,
    @SerializedName("interrupted") val interrupted: Boolean = false,
    @SerializedName("error") val error: JsonElement? = null,
)

data class UsageDto(
    @SerializedName("input_tokens") val inputTokens: Long = 0,
    @SerializedName("output_tokens") val outputTokens: Long = 0,
    @SerializedName("total_tokens") val totalTokens: Long = 0,
    @SerializedName("cache_read_tokens") val cacheReadTokens: Long = 0,
    @SerializedName("cache_write_tokens") val cacheWriteTokens: Long = 0,
)

data class RuntimeDto(
    @SerializedName("provider") val provider: String? = null,
    @SerializedName("model") val model: String? = null,
    @SerializedName("route_source") val routeSource: String? = null,
)

/** SSE payloads from GET /v1/runs/{id}/events */
data class RunEventDto(
    @SerializedName("event") val event: String? = null,
    @SerializedName("run_id") val runId: String? = null,
    @SerializedName("seq") val seq: Long? = null,
    @SerializedName("timestamp") val timestamp: Double? = null,
    @SerializedName("delta") val delta: String? = null,
    @SerializedName("text") val text: String? = null,
    @SerializedName("output") val output: String? = null,
    @SerializedName("already_streamed") val alreadyStreamed: Boolean = false,
    @SerializedName("tool") val tool: String? = null,
    @SerializedName("tool_name") val toolName: String? = null,
    @SerializedName("duration") val duration: Double? = null,
    @SerializedName("error") val error: JsonElement? = null,
    @SerializedName("preview") val preview: JsonElement? = null,
    @SerializedName("usage") val usage: UsageDto? = null,
    @SerializedName("runtime") val runtime: RuntimeDto? = null,
    @SerializedName("completed") val completed: Boolean? = null,
    @SerializedName("partial") val partial: Boolean? = null,
    @SerializedName("interrupted") val interrupted: Boolean? = null,
    @SerializedName("subagent_id") val subagentId: String? = null,
    @SerializedName("title") val title: String? = null,
    @SerializedName("status") val status: String? = null,
)

/** POST /v1/runs/{id}/steer */
data class SteerRequest(
    @SerializedName("input") val input: String,
)

/** GET /api/sessions/{id}/messages */
data class SessionMessagesResponse(
    @SerializedName("object") val objectType: String? = null,
    @SerializedName("session_id") val sessionId: String? = null,
    @SerializedName("data") val data: List<ServerMessage> = emptyList(),
    @SerializedName("pagination") val pagination: JsonElement? = null,
)

data class ServerMessage(
    @SerializedName("id") val id: Long? = null,
    @SerializedName("session_id") val sessionId: String? = null,
    @SerializedName("role") val role: String? = null,
    @SerializedName("content") val content: JsonElement? = null,
    @SerializedName("tool_call_id") val toolCallId: String? = null,
    @SerializedName("tool_calls") val toolCalls: JsonElement? = null,
    @SerializedName("tool_name") val toolName: String? = null,
    @SerializedName("timestamp") val timestamp: Double? = null,
    @SerializedName("token_count") val tokenCount: Long? = null,
    @SerializedName("finish_reason") val finishReason: String? = null,
    @SerializedName("reasoning") val reasoning: String? = null,
    @SerializedName("reasoning_content") val reasoningContent: String? = null,
    @SerializedName("display_kind") val displayKind: String? = null,
)
