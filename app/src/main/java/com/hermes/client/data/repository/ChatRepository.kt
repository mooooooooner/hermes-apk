package com.hermes.client.data.repository

import android.content.Context
import android.net.Uri
import android.util.Base64
import com.hermes.client.data.local.HermesDatabase
import com.hermes.client.data.local.MessageEntity
import com.hermes.client.data.local.RunEntity
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.AttachmentKind
import com.hermes.client.data.model.ChatMessage
import com.hermes.client.data.model.MessageRole
import com.hermes.client.data.model.MessageStatus
import com.hermes.client.data.model.RunState
import com.hermes.client.data.remote.HermesApi
import com.hermes.client.data.remote.dto.AttachmentPayload
import com.hermes.client.data.remote.dto.HistoryMessage
import com.hermes.client.data.remote.dto.RunRequest
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.worker.WorkScheduler
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Orchestrates chat: persists the user turn, submits an async run, and delegates streaming /
 * recovery to [RunManager].
 */
@Singleton
class ChatRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val api: HermesApi,
    private val db: HermesDatabase,
    private val settings: SettingsRepository,
    private val runManager: RunManager,
    private val workScheduler: WorkScheduler,
) {
    private val messageDao get() = db.messageDao()
    private val runDao get() = db.runDao()
    private val sessionDao get() = db.sessionDao()

    fun observeMessages(sessionId: String): Flow<List<ChatMessage>> =
        combine(
            messageDao.observe(sessionId),
            runDao.observeForSession(sessionId),
        ) { messages, runs ->
            val runsById = runs.associateBy { it.runId }
            messages.map { entity ->
                val state = entity.runId?.let { runsById[it]?.toDomainState() }
                entity.toDomain(state)
            }
        }

    suspend fun sendMessage(
        sessionId: String,
        text: String,
        attachments: List<Attachment> = emptyList(),
    ): Result<String> {
        val now = System.currentTimeMillis()
        val seq = (messageDao.maxSeq(sessionId) ?: 0) + 1
        messageDao.insert(
            MessageEntity(
                sessionId = sessionId,
                role = MessageRole.USER.name,
                content = text,
                status = MessageStatus.COMPLETE.name,
                seq = seq,
                createdAt = now,
                updatedAt = now,
                attachments = attachments,
            ),
        )
        return submit(sessionId, text, attachments)
    }

    /** Re-run an existing user turn, discarding everything that came after it. */
    suspend fun resend(userMessageId: Long): Result<String> {
        val message = messageDao.get(userMessageId) ?: return Result.failure(IllegalArgumentException("消息不存在"))
        truncateAfter(message.sessionId, message.seq)
        return submit(message.sessionId, message.content, message.attachments)
    }

    /** Edit a user turn in place and re-run it. */
    suspend fun editAndResend(userMessageId: Long, newText: String): Result<String> {
        val message = messageDao.get(userMessageId) ?: return Result.failure(IllegalArgumentException("消息不存在"))
        messageDao.update(
            message.copy(content = newText, updatedAt = System.currentTimeMillis()),
        )
        truncateAfter(message.sessionId, message.seq)
        return submit(message.sessionId, newText, message.attachments)
    }

    private suspend fun truncateAfter(sessionId: String, seq: Int) {
        messageDao.list(sessionId)
            .filter { it.seq > seq || (it.seq == seq && it.role == MessageRole.ASSISTANT.name) }
            .forEach { messageDao.delete(it.id) }
    }

    private suspend fun submit(
        sessionId: String,
        text: String,
        attachments: List<Attachment>,
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            if (sessionDao.get(sessionId) == null) {
                val createdAt = System.currentTimeMillis()
                sessionDao.upsert(
                    com.hermes.client.data.local.SessionEntity(
                        id = sessionId,
                        title = text.take(24).ifBlank { "新会话" },
                        createdAt = createdAt,
                        updatedAt = createdAt,
                    ),
                )
            }

            val now = System.currentTimeMillis()
            val seq = (messageDao.maxSeq(sessionId) ?: 0) + 1
            val assistantId = messageDao.insert(
                MessageEntity(
                    sessionId = sessionId,
                    role = MessageRole.ASSISTANT.name,
                    content = "",
                    status = MessageStatus.PENDING.name,
                    seq = seq,
                    createdAt = now,
                    updatedAt = now,
                ),
            )

            val settingsSnapshot = settings.snapshot()
            val built = buildInput(text, attachments)
            val request = RunRequest(
                input = built.text,
                sessionId = sessionId,
                instructions = settingsSnapshot.systemInstructions.ifBlank { null },
                attachments = built.payloads.ifEmpty { null },
            )
            val created = api.createRun(request, idempotencyKey = UUID.randomUUID().toString())

            runDao.upsert(
                RunEntity(
                    runId = created.runId,
                    sessionId = sessionId,
                    userMessageId = null,
                    assistantMessageId = assistantId,
                    status = RunState.STARTED.name,
                    createdAt = now,
                    updatedAt = now,
                ),
            )
            messageDao.bindRun(assistantId, created.runId, MessageStatus.STREAMING.name)
            sessionDao.setActiveRun(sessionId, created.runId, RunState.RUNNING.name)
            sessionDao.touch(sessionId, now, text.take(120))

            runManager.attach(created.runId, sessionId)
            workScheduler.scheduleOneTimeReconcile()
            created.runId
        }.onFailure { error ->
            // Mark the orphan placeholder so the UI doesn't spin forever.
            runCatching {
                val last = messageDao.list(sessionId).lastOrNull { it.runId == null && it.role == MessageRole.ASSISTANT.name }
                if (last != null) {
                    messageDao.update(
                        last.copy(
                            status = MessageStatus.ERROR.name,
                            error = error.message ?: "发起任务失败",
                            updatedAt = System.currentTimeMillis(),
                        ),
                    )
                }
                sessionDao.setActiveRun(sessionId, null, null)
            }
        }
    }

    suspend fun fetchHistory(sessionId: String): Result<Int> = withContext(Dispatchers.IO) {
        runCatching {
            // Replacing the local messages would orphan the row that an in-flight stream writes
            // into (RunEntity.assistantMessageId points at it), so refuse while a task is running.
            val hasActive = messageDao.list(sessionId).any {
                it.status == MessageStatus.STREAMING.name || it.status == MessageStatus.PENDING.name
            }
            check(!hasActive) { "任务进行中，请等待完成或中断后再同步历史" }

            val response = api.sessionMessages(sessionId)
            if (response.data.isEmpty()) return@runCatching 0
            // Server is authoritative: replace the local cache with the server transcript.
            messageDao.deleteForSession(sessionId)
            val startSeq = (messageDao.maxSeq(sessionId) ?: 0)
            response.data.forEachIndexed { index, server ->
                val role = when (server.role) {
                    "user" -> MessageRole.USER.name
                    "assistant" -> MessageRole.ASSISTANT.name
                    "tool" -> MessageRole.TOOL.name
                    "system" -> MessageRole.SYSTEM.name
                    else -> MessageRole.ASSISTANT.name
                }
                messageDao.insert(
                    MessageEntity(
                        sessionId = sessionId,
                        role = role,
                        content = server.content.contentToText(),
                        reasoning = server.reasoning ?: server.reasoningContent.orEmpty(),
                        status = MessageStatus.COMPLETE.name,
                        seq = startSeq + index + 1,
                        createdAt = ((server.timestamp ?: 0.0) * 1000).toLong()
                            .takeIf { it > 0 } ?: System.currentTimeMillis(),
                        updatedAt = System.currentTimeMillis(),
                        attachments = server.content.contentToAttachments(),
                        serverId = server.id,
                    ),
                )
            }
            response.data.size
        }
    }

    suspend fun deleteMessage(messageId: Long) {
        messageDao.delete(messageId)
    }

    private data class BuiltInput(
        val text: String,
        val payloads: List<AttachmentPayload>,
    )

    private suspend fun buildInput(
        text: String,
        attachments: List<Attachment>,
    ): BuiltInput = withContext(Dispatchers.IO) {
        if (attachments.isEmpty()) return@withContext BuiltInput(text, emptyList())
        val blocks = mutableListOf<String>()
        val payloads = mutableListOf<AttachmentPayload>()
        attachments.forEach { attachment ->
            val bytes = runCatching { readBytes(Uri.parse(attachment.uri)) }.getOrNull() ?: return@forEach
            when {
                attachment.mimeType.startsWith("text/") || attachment.mimeType == "application/json" -> {
                    val body = String(bytes, Charsets.UTF_8).take(MAX_TEXT_CHARS)
                    blocks += "附件 `${attachment.name}`:\n```\n$body\n```"
                    payloads += AttachmentPayload(
                        type = attachment.mimeType,
                        name = attachment.name,
                        data = Base64.encodeToString(body.toByteArray(), Base64.NO_WRAP),
                    )
                }

                attachment.kind == AttachmentKind.IMAGE -> {
                    val dataUrl = "data:${attachment.mimeType};base64," +
                        Base64.encodeToString(bytes, Base64.NO_WRAP)
                    blocks += "![${attachment.name}]($dataUrl)"
                    payloads += AttachmentPayload(
                        type = attachment.mimeType,
                        name = attachment.name,
                        data = dataUrl,
                    )
                }

                else -> {
                    blocks += "（已附加文件 `${attachment.name}`，${attachment.size} 字节）"
                    payloads += AttachmentPayload(
                        type = attachment.mimeType,
                        name = attachment.name,
                        data = Base64.encodeToString(bytes, Base64.NO_WRAP),
                    )
                }
            }
        }
        val combined = buildString {
            append(text)
            if (blocks.isNotEmpty()) {
                if (isNotEmpty()) append("\n\n")
                append(blocks.joinToString("\n\n"))
            }
        }
        BuiltInput(combined, payloads)
    }

    private fun readBytes(uri: Uri): ByteArray? =
        context.contentResolver.openInputStream(uri)?.use { it.readBytes() }

    private companion object {
        const val MAX_TEXT_CHARS = 200_000
    }
}
