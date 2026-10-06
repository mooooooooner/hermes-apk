package com.hermes.client.data.repository

import com.google.gson.JsonElement
import com.google.gson.JsonPrimitive
import com.hermes.client.data.local.MessageEntity
import com.hermes.client.data.local.RunEntity
import com.hermes.client.data.local.SessionEntity
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.ChatMessage
import com.hermes.client.data.model.ChatSession
import com.hermes.client.data.model.MessageRole
import com.hermes.client.data.model.MessageStatus
import com.hermes.client.data.model.RunState
import com.hermes.client.data.model.Usage

fun SessionEntity.toDomain() = ChatSession(
    id = id,
    title = title,
    createdAt = createdAt,
    updatedAt = updatedAt,
    preview = preview,
    activeRunId = activeRunId,
    activeRunState = activeRunState?.let { RunState.from(it) },
)

fun MessageEntity.toDomain(runState: RunState? = null) = ChatMessage(
    id = id,
    sessionId = sessionId,
    role = runCatching { MessageRole.valueOf(role) }.getOrDefault(MessageRole.ASSISTANT),
    content = content,
    reasoning = reasoning,
    status = runCatching { MessageStatus.valueOf(status) }.getOrDefault(MessageStatus.COMPLETE),
    runId = runId,
    seq = seq,
    createdAt = createdAt,
    updatedAt = updatedAt,
    attachments = attachments,
    toolEvents = toolEvents,
    error = error,
    usage = usage,
    runState = runState,
)

fun RunEntity.toDomainState(): RunState = RunState.from(status)

/** Extract plain text from a server message `content` which may be a string or an array of parts. */
fun JsonElement?.contentToText(): String {
    if (this == null) return ""
    return when {
        isJsonPrimitive -> (this as JsonPrimitive).let { if (it.isString) it.asString else it.toString() }
        isJsonArray -> asJsonArray.joinToString("\n") { part ->
            runCatching {
                val obj = part.asJsonObject
                val type = obj.get("type")?.asString
                when (type) {
                    "input_text", "text", "output_text" -> obj.get("text")?.asString.orEmpty()
                    "image_url", "input_image" -> "[图片]"
                    else -> obj.get("text")?.asString ?: ""
                }
            }.getOrDefault("")
        }.trim()
        else -> toString()
    }
}

/** Extract image / file attachments from a server message content array, if any. */
fun JsonElement?.contentToAttachments(serverIds: List<String> = emptyList()): List<Attachment> {
    if (this == null || !isJsonArray) return emptyList()
    return asJsonArray.mapIndexedNotNull { index, part ->
        runCatching {
            val obj = part.asJsonObject
            val type = obj.get("type")?.asString
            if (type == "image_url" || type == "input_image") {
                val url = obj.get("image_url")?.let { iu ->
                    if (iu.isJsonObject) iu.asJsonObject.get("url")?.asString else iu.asString
                } ?: return@runCatching null
                Attachment(
                    id = serverIds.getOrNull(index) ?: "server-img-$index",
                    name = "image-$index",
                    mimeType = "image/*",
                    size = 0,
                    uri = url,
                    kind = com.hermes.client.data.model.AttachmentKind.IMAGE,
                )
            } else null
        }.getOrNull()
    }
}

fun com.hermes.client.data.remote.dto.UsageDto.toDomain() = Usage(
    inputTokens = inputTokens,
    outputTokens = outputTokens,
    totalTokens = totalTokens,
    cacheReadTokens = cacheReadTokens,
    cacheWriteTokens = cacheWriteTokens,
)
