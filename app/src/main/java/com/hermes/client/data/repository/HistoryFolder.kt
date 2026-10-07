package com.hermes.client.data.repository

import com.google.gson.JsonElement
import com.hermes.client.data.local.MessageEntity
import com.hermes.client.data.model.MessageRole
import com.hermes.client.data.model.MessageSegment
import com.hermes.client.data.model.MessageStatus
import com.hermes.client.data.model.ToolEvent
import com.hermes.client.data.remote.dto.ServerMessage

/**
 * Folds the server transcript (assistant turns + their tool results) into the same ordered
 * [MessageSegment] model the streaming path produces, so a synced conversation renders identically
 * to one that was streamed live.
 *
 * Shared by manual sync ([ChatRepository.fetchHistory]) and the silent post-completion refresh in
 * [RunManager], so both paths produce byte-for-byte the same local shape.
 */
object HistoryFolder {

    fun fold(
        sessionId: String,
        data: List<ServerMessage>,
        previous: List<MessageEntity> = emptyList(),
        now: Long = System.currentTimeMillis(),
    ): List<MessageEntity> {
        val entities = mutableListOf<MessageEntity>()
        val pending = mutableListOf<ServerMessage>()

        // Local user messages, consumed in order, so attachments survive a server sync (the server
        // transcript does not carry the app's local attachment URIs).
        val previousUsers = previous
            .filter { it.role == MessageRole.USER.name }
            .toMutableList()

        fun flushAssistant() {
            if (pending.isEmpty()) return
            val segments = buildSegments(pending)
            pending.clear()
            if (segments.none { !it.isEmpty }) return
            entities += MessageEntity(
                sessionId = sessionId,
                role = MessageRole.ASSISTANT.name,
                content = segments.map { it.text.trim() }.filter { it.isNotEmpty() }
                    .joinToString("\n\n"),
                reasoning = segments.map { it.reasoning.trim() }.filter { it.isNotEmpty() }
                    .joinToString("\n\n"),
                status = MessageStatus.COMPLETE.name,
                seq = entities.size + 1,
                createdAt = now,
                updatedAt = now,
                toolEvents = segments.flatMap { it.tools },
                segments = segments,
            )
        }

        data.forEach { server ->
            when (server.role) {
                "user" -> {
                    flushAssistant()
                    val content = server.content.contentToText()
                    val matchIndex = previousUsers.indexOfFirst { it.content == content }
                    val preserved = if (matchIndex >= 0) {
                        previousUsers.removeAt(matchIndex).attachments
                    } else {
                        emptyList()
                    }
                    entities += MessageEntity(
                        sessionId = sessionId,
                        role = MessageRole.USER.name,
                        content = content,
                        status = MessageStatus.COMPLETE.name,
                        seq = entities.size + 1,
                        createdAt = ((server.timestamp ?: 0.0) * 1000).toLong()
                            .takeIf { it > 0 } ?: now,
                        updatedAt = now,
                        attachments = preserved.ifEmpty { server.content.contentToAttachments() },
                        serverId = server.id,
                    )
                }

                "assistant", "tool" -> pending += server
                else -> Unit
            }
        }
        flushAssistant()
        return entities
    }

    private fun buildSegments(messages: List<ServerMessage>): List<MessageSegment> {
        val segments = mutableListOf<MessageSegment>()
        messages.forEach { message ->
            when (message.role) {
                "assistant" -> segments += MessageSegment(
                    reasoning = (message.reasoning ?: message.reasoningContent).orEmpty(),
                    tools = parseToolCalls(message.toolCalls),
                    text = message.content.contentToText(),
                )

                "tool" -> {
                    val result = message.content.contentToText()
                    val id = message.toolCallId
                    var matched = false
                    if (id != null) {
                        for (i in segments.indices.reversed()) {
                            val tools = segments[i].tools
                            val index = tools.indexOfFirst { it.id == id }
                            if (index >= 0) {
                                val copy = tools.toMutableList()
                                copy[index] = copy[index].copy(status = "completed", result = result)
                                segments[i] = segments[i].copy(tools = copy)
                                matched = true
                                break
                            }
                        }
                    }
                    if (!matched) {
                        for (i in segments.indices) {
                            val tools = segments[i].tools
                            val index = tools.indexOfFirst { it.result == null }
                            if (index >= 0) {
                                val copy = tools.toMutableList()
                                copy[index] = copy[index].copy(
                                    status = "completed",
                                    result = result,
                                    name = copy[index].name.ifBlank { message.toolName ?: "tool" },
                                )
                                segments[i] = segments[i].copy(tools = copy)
                                matched = true
                                break
                            }
                        }
                    }
                    if (!matched) {
                        segments += MessageSegment(
                            tools = listOf(
                                ToolEvent(
                                    id = id ?: "tool-${segments.size}",
                                    name = message.toolName ?: "tool",
                                    status = "completed",
                                    result = result,
                                ),
                            ),
                        )
                    }
                }
            }
        }
        return segments
    }

    private fun parseToolCalls(element: JsonElement?): List<ToolEvent> {
        if (element == null || !element.isJsonArray) return emptyList()
        return element.asJsonArray.mapIndexedNotNull { index, part ->
            runCatching {
                val obj = part.asJsonObject
                val id = obj.get("id")?.asString
                    ?: obj.get("call_id")?.asString
                    ?: "call-$index"
                val function = obj.getAsJsonObject("function")
                val name = function?.get("name")?.asString
                    ?: obj.get("name")?.asString
                    ?: "tool"
                val arguments = function?.get("arguments")?.let {
                    if (it.isJsonPrimitive) it.asString else it.toString()
                }
                ToolEvent(id = id, name = name, status = "started", preview = arguments)
            }.getOrNull()
        }
    }
}
