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
    val error: String?,
    val usage: Usage?,
    val runState: RunState?,
)

data class ChatSession(
    val id: String,
    val title: String,
    val createdAt: Long,
    val updatedAt: Long,
    val preview: String,
    val activeRunId: String?,
    val activeRunState: RunState?,
)
