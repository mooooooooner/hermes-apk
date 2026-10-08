package com.hermes.client.data.repository

import android.content.Context
import android.net.Uri
import android.util.Base64
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive
import com.hermes.client.data.local.HermesDatabase
import com.hermes.client.data.local.MessageEntity
import com.hermes.client.data.local.RunEntity
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.AttachmentKind
import com.hermes.client.data.model.ChatMessage
import com.hermes.client.data.model.MessageRole
import com.hermes.client.data.model.MessageStatus
import com.hermes.client.data.model.RunState
import com.hermes.client.data.prefs.AppSettings
import com.hermes.client.data.remote.HermesApi
import com.hermes.client.data.remote.dto.RunRequest
import com.hermes.client.data.remote.dto.UploadedFileDto
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.worker.WorkScheduler
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CancellationException
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
    private val fileService: FileServiceRepository,
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
        var assistantId: Long? = null
        try {
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
            val placeholderId = messageDao.insert(
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
            assistantId = placeholderId
            // Guard the placeholder from the orphan sweep while this network call is in flight.
            runManager.markSubmitInFlight(placeholderId)

            val settingsSnapshot = settings.snapshot()
            // Ship attachments to the file service so the agent can read them by local path. Only
            // the ones that fail to upload fall back to being inlined in the run input.
            val (uploaded, failed) = uploadAttachments(attachments)
            val input = buildInput(text, failed)
            val request = RunRequest(
                input = input,
                sessionId = sessionId,
                instructions = buildInstructions(settingsSnapshot, uploaded),
            )
            val created = api.createRun(request, idempotencyKey = UUID.randomUUID().toString())

            runDao.upsert(
                RunEntity(
                    runId = created.runId,
                    sessionId = sessionId,
                    userMessageId = null,
                    assistantMessageId = placeholderId,
                    status = RunState.STARTED.name,
                    createdAt = now,
                    updatedAt = now,
                ),
            )
            messageDao.bindRun(placeholderId, created.runId, MessageStatus.STREAMING.name)
            sessionDao.setActiveRun(sessionId, created.runId, RunState.RUNNING.name)
            sessionDao.touch(sessionId, now, text.take(120))

            runManager.attach(created.runId, sessionId)
            workScheduler.scheduleOneTimeReconcile()
            Result.success(created.runId)
        } catch (cancellation: CancellationException) {
            // stop() cancelled us before the run existed; leave the placeholder to cancelPending().
            throw cancellation
        } catch (error: Exception) {
            // Mark the orphan placeholder so the UI doesn't spin forever.
            runCatching {
                assistantId?.let { id ->
                    messageDao.get(id)?.takeIf { it.runId == null }?.let { message ->
                        messageDao.update(
                            message.copy(
                                status = MessageStatus.ERROR.name,
                                error = error.message ?: "发起任务失败",
                                updatedAt = System.currentTimeMillis(),
                            ),
                        )
                    }
                }
                sessionDao.setActiveRun(sessionId, null, null)
            }
            Result.failure(error)
        } finally {
            assistantId?.let { runManager.clearSubmitInFlight(it) }
        }
    }

    /**
     * Cancel a placeholder that never became a run: either a send that is still in flight when the
     * user hits interrupt, or one abandoned by a crash. Returns how many were cleared.
     */
    suspend fun cancelPending(sessionId: String): Int = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        val pending = messageDao.list(sessionId).filter {
            it.status == MessageStatus.PENDING.name && it.runId == null
        }
        pending.forEach { message ->
            messageDao.update(
                message.copy(
                    status = MessageStatus.CANCELLED.name,
                    error = "已取消",
                    updatedAt = now,
                ),
            )
        }
        sessionDao.setActiveRun(sessionId, null, null)
        pending.size
    }

    private suspend fun uploadAttachments(
        attachments: List<Attachment>,
    ): Pair<List<UploadedFileDto>, List<Attachment>> {
        if (attachments.isEmpty()) return emptyList<UploadedFileDto>() to emptyList()
        val uploaded = mutableListOf<UploadedFileDto>()
        val failed = mutableListOf<Attachment>()
        attachments.forEach { attachment ->
            val result = fileService.upload(attachment)
            if (result?.path != null) uploaded += result else failed += attachment
        }
        return uploaded to failed
    }

    /** Ephemeral system prompt: user instructions + how to read uploaded files / send files back. */
    private fun buildInstructions(
        settingsSnapshot: AppSettings,
        uploaded: List<UploadedFileDto>,
    ): String? {
        val parts = mutableListOf<String>()
        if (settingsSnapshot.systemInstructions.isNotBlank()) {
            parts += settingsSnapshot.systemInstructions.trim()
        }
        if (uploaded.isNotEmpty()) {
            val list = uploaded.joinToString("\n") {
                "- ${it.name ?: it.id}（${it.mime ?: "application/octet-stream"}, ${it.size} 字节）：${it.path}"
            }
            parts += "【用户上传的文件】用户本次消息附带了以下文件，已保存到服务器本机。请直接用文件工具读取其绝对路径来分析，不要凭猜测回答：\n$list"
        }
        val filesBase = settingsSnapshot.effectiveFilesBaseUrl
        if (filesBase.isNotBlank() && settingsSnapshot.apiKey.isNotBlank()) {
            parts += "【向用户发送文件/图片】当你需要把生成的图片或文件发给用户时，先写入磁盘，再用 terminal 执行：\n" +
                "curl -s -F 'file=@<文件的绝对路径>' -H 'Authorization: Bearer ${settingsSnapshot.apiKey}' '$filesBase/upload'\n" +
                "响应 JSON 中的 url 字段就是用户可访问的地址。图片请用 Markdown 图片语法 ![说明](url) 直接展示；其它文件请单独一行输出 MEDIA:url 。"
        }
        return parts.joinToString("\n\n").ifBlank { null }
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
            // Server is authoritative: replace the local cache, but rebuild it in the same shape
            // the streaming path produces so the format does not change after a manual sync.
            val previous = messageDao.list(sessionId)
            val entities = HistoryFolder.fold(sessionId, response.data, previous)
            messageDao.deleteForSession(sessionId)
            entities.forEach { messageDao.insert(it) }
            entities.size
        }
    }

    suspend fun deleteMessage(messageId: Long) {
        messageDao.delete(messageId)
    }

    /**
     * Build the `POST /v1/runs` `input` payload for attachments that could **not** be uploaded to
     * the file service (offline / unsupported). Images become native OpenAI-style `image_url`
     * content parts; text files are inlined as fenced text. With no attachments the input stays a
     * plain string.
     */
    private suspend fun buildInput(
        text: String,
        attachments: List<Attachment>,
    ): JsonElement = withContext(Dispatchers.IO) {
        if (attachments.isEmpty()) return@withContext JsonPrimitive(text)

        val textBlocks = mutableListOf<String>()
        val imageParts = mutableListOf<JsonElement>()

        attachments.forEach { attachment ->
            val bytes = runCatching { readBytes(Uri.parse(attachment.uri)) }.getOrNull()
                ?: return@forEach
            when {
                attachment.kind == AttachmentKind.IMAGE -> {
                    val mime = attachment.mimeType.ifBlank { "image/png" }
                    val dataUrl = "data:$mime;base64," + Base64.encodeToString(bytes, Base64.NO_WRAP)
                    imageParts += JsonObject().apply {
                        addProperty("type", "image_url")
                        add("image_url", JsonObject().apply {
                            addProperty("url", dataUrl)
                            addProperty("detail", "auto")
                        })
                    }
                }

                attachment.mimeType.startsWith("text/") || attachment.mimeType == "application/json" -> {
                    val body = String(bytes, Charsets.UTF_8).take(MAX_TEXT_CHARS)
                    textBlocks += "附件 `${attachment.name}`:\n```\n$body\n```"
                }

                else -> {
                    textBlocks += "（已附加文件 `${attachment.name}`，${attachment.size} 字节；上传失败，请让用户重新发送或提供可访问的 URL）"
                }
            }
        }

        val combined = buildString {
            append(text)
            if (textBlocks.isNotEmpty()) {
                if (isNotBlank()) append("\n\n")
                append(textBlocks.joinToString("\n\n"))
            }
        }

        if (imageParts.isEmpty()) {
            JsonPrimitive(combined)
        } else {
            // `input` as a list of messages: the server reads only the *last* message's content as
            // the user turn (earlier entries would be treated as history), so we send exactly one.
            val content = JsonArray().apply {
                add(JsonObject().apply {
                    addProperty("type", "text")
                    addProperty("text", combined.ifBlank { "请查看附件。" })
                })
                imageParts.forEach { add(it) }
            }
            JsonArray().apply {
                add(JsonObject().apply {
                    addProperty("role", "user")
                    add("content", content)
                })
            }
        }
    }

    private fun readBytes(uri: Uri): ByteArray? =
        context.contentResolver.openInputStream(uri)?.use { it.readBytes() }

    private companion object {
        const val MAX_TEXT_CHARS = 200_000
    }
}
