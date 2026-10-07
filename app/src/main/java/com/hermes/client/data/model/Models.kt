package com.hermes.client.data.model

enum class MessageRole { USER, ASSISTANT, SYSTEM, TOOL }

enum class MessageStatus { PENDING, STREAMING, COMPLETE, ERROR, CANCELLED }

enum class AttachmentKind { IMAGE, FILE }

data class Attachment(
    val id: String,
    val name: String,
    val mimeType: String,
    val size: Long,
    val uri: String,
    val kind: AttachmentKind,
)

data class ToolEvent(
    val id: String,
    val name: String,
    val status: String,          // started | completed | subagent_start | subagent_complete
    val preview: String? = null, // tool arguments (pretty printed)
    val result: String? = null,  // tool result preview (truncated by server)
    val durationMs: Long? = null,
    val error: Boolean = false,
    val startedAt: Long = 0,
)

data class Usage(
    val inputTokens: Long = 0,
    val outputTokens: Long = 0,
    val totalTokens: Long = 0,
    val cacheReadTokens: Long = 0,
    val cacheWriteTokens: Long = 0,
)

/**
 * One "round" of an agent turn, rendered in order as 思维链 → toolcall → 正文.
 *
 * Hermes runs an agent loop: each iteration produces reasoning, zero or more tool calls, and
 * (optionally) interim assistant text. The stream exposes those as `reasoning.*`, `tool.*`,
 * `message.delta` / `message.interim` events. Grouping them into segments keeps the timeline
 * faithful instead of flattening every round into a single reasoning/tool/text blob.
 */
data class MessageSegment(
    val reasoning: String = "",
    val tools: List<ToolEvent> = emptyList(),
    val text: String = "",
) {
    val isEmpty: Boolean get() = reasoning.isBlank() && tools.isEmpty() && text.isBlank()
}

enum class RunState {
    QUEUED, STARTED, RUNNING, COMPLETED, FAILED, CANCELLED, INTERRUPTED, UNKNOWN;

    val isTerminal: Boolean
        get() = this == COMPLETED || this == FAILED || this == CANCELLED || this == INTERRUPTED

    val isActive: Boolean
        get() = !isTerminal

    companion object {
        fun from(raw: String?): RunState = when (raw?.lowercase()) {
            "queued" -> QUEUED
            "started" -> STARTED
            "running", "in_progress" -> RUNNING
            "completed", "complete", "succeeded" -> COMPLETED
            "failed", "error" -> FAILED
            "cancelled", "canceled" -> CANCELLED
            "interrupted" -> INTERRUPTED
            else -> UNKNOWN
        }
    }
}

/** UI-facing aggregate of a chat message. */
data class ChatMessage(
    val id: Long,
    val sessionId: String,
    val role: MessageRole,
    val content: String,
    val reasoning: String,
    val status: MessageStatus,
    val runId: String?,
    val seq: Int,
    val createdAt: Long,
    val updatedAt: Long,
    val attachments: List<Attachment>,
    val toolEvents: List<ToolEvent>,
    val segments: List<MessageSegment> = emptyList(),
    val error: String?,
    val usage: Usage?,
    val runState: RunState?,
) {
    /** Segments to render; synthesised from legacy aggregate fields when absent. */
    val renderSegments: List<MessageSegment>
        get() = if (segments.isNotEmpty()) segments else listOf(
            MessageSegment(reasoning = reasoning, tools = toolEvents, text = content),
        ).filterNot { it.isEmpty }

    /** The final answer (last non-blank segment text), used for previews and notifications. */
    val finalText: String
        get() = renderSegments.lastOrNull { it.text.isNotBlank() }?.text ?: content
}

data class ChatSession(
    val id: String,
    val title: String,
    val createdAt: Long,
    val updatedAt: Long,
    val preview: String,
    val activeRunId: String?,
    val activeRunState: RunState?,
)
