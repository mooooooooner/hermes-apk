package com.hermes.client.data.repository

import com.google.gson.JsonPrimitive
import com.hermes.client.data.local.MessageEntity
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.AttachmentKind
import com.hermes.client.data.model.MessageRole
import com.hermes.client.data.remote.dto.ServerMessage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryFolderTest {

    @Test
    fun foldsAssistantTurnIntoOrderedSegments() {
        val data = listOf(
            ServerMessage(role = "user", content = JsonPrimitive("hi")),
            ServerMessage(role = "assistant", reasoning = "think", content = JsonPrimitive("answer")),
        )
        val entities = HistoryFolder.fold("s", data, now = 1L)

        assertEquals(2, entities.size)
        assertEquals(MessageRole.USER.name, entities[0].role)
        assertEquals(MessageRole.ASSISTANT.name, entities[1].role)
        assertEquals("think", entities[1].segments[0].reasoning)
        assertEquals("answer", entities[1].segments[0].text)
    }

    @Test
    fun preservesLocalAttachmentsAcrossSync() {
        val attachment = Attachment(
            id = "a1",
            name = "photo.png",
            mimeType = "image/png",
            size = 12,
            uri = "content://local/photo",
            kind = AttachmentKind.IMAGE,
        )
        val previous = listOf(
            MessageEntity(sessionId = "s", role = MessageRole.USER.name, content = "看这个", attachments = listOf(attachment)),
        )
        val data = listOf(
            ServerMessage(role = "user", content = JsonPrimitive("看这个")),
            ServerMessage(role = "assistant", content = JsonPrimitive("好")),
        )
        val entities = HistoryFolder.fold("s", data, previous, now = 1L)

        assertEquals(1, entities[0].attachments.size)
        assertEquals("content://local/photo", entities[0].attachments[0].uri)
    }

    @Test
    fun keepsSlashCommandTurnTheServerNeverPersisted() {
        val previous = listOf(
            MessageEntity(sessionId = "s", role = MessageRole.USER.name, content = "hi", seq = 1),
            MessageEntity(sessionId = "s", role = MessageRole.ASSISTANT.name, content = "hello", seq = 2),
            MessageEntity(sessionId = "s", role = MessageRole.USER.name, content = "/status", seq = 3),
            MessageEntity(sessionId = "s", role = MessageRole.ASSISTANT.name, content = "STATUS OUTPUT", seq = 4),
        )
        // The server transcript only holds the normal turn: /status was answered server-side.
        val data = listOf(
            ServerMessage(role = "user", content = JsonPrimitive("hi")),
            ServerMessage(role = "assistant", content = JsonPrimitive("hello")),
        )
        val entities = HistoryFolder.fold("s", data, previous, now = 1L)

        assertEquals(4, entities.size)
        assertEquals("hi", entities[0].content)
        assertEquals("hello", entities[1].content)
        assertEquals("/status", entities[2].content)
        assertEquals("STATUS OUTPUT", entities[3].content)
        // Sequence numbers stay contiguous so the UI keeps the original order.
        assertEquals(listOf(1, 2, 3, 4), entities.map { it.seq })
    }

    @Test
    fun keepsSlashCommandTurnBetweenTwoServerTurns() {
        val previous = listOf(
            MessageEntity(sessionId = "s", role = MessageRole.USER.name, content = "hi", seq = 1),
            MessageEntity(sessionId = "s", role = MessageRole.ASSISTANT.name, content = "hello", seq = 2),
            MessageEntity(sessionId = "s", role = MessageRole.USER.name, content = "/usage", seq = 3),
            MessageEntity(sessionId = "s", role = MessageRole.ASSISTANT.name, content = "no usage", seq = 4),
            MessageEntity(sessionId = "s", role = MessageRole.USER.name, content = "bye", seq = 5),
            MessageEntity(sessionId = "s", role = MessageRole.ASSISTANT.name, content = "bye2", seq = 6),
        )
        val data = listOf(
            ServerMessage(role = "user", content = JsonPrimitive("hi")),
            ServerMessage(role = "assistant", content = JsonPrimitive("hello")),
            ServerMessage(role = "user", content = JsonPrimitive("bye")),
            ServerMessage(role = "assistant", content = JsonPrimitive("bye2")),
        )
        val entities = HistoryFolder.fold("s", data, previous, now = 1L)

        assertEquals(listOf("hi", "hello", "/usage", "no usage", "bye", "bye2"), entities.map { it.content })
    }

    @Test
    fun doesNotDuplicateAnUnknownSlashMessageTheServerDidPersist() {
        val previous = listOf(
            MessageEntity(sessionId = "s", role = MessageRole.USER.name, content = "/foo", seq = 1),
            MessageEntity(sessionId = "s", role = MessageRole.ASSISTANT.name, content = "resp", seq = 2),
        )
        val data = listOf(
            ServerMessage(role = "user", content = JsonPrimitive("/foo")),
            ServerMessage(role = "assistant", content = JsonPrimitive("resp")),
        )
        val entities = HistoryFolder.fold("s", data, previous, now = 1L)

        assertEquals(2, entities.size)
        assertEquals("/foo", entities[0].content)
        assertEquals("resp", entities[1].content)
    }

    @Test
    fun groupsToolResultsIntoTheSourcingSegment() {
        val toolCalls = com.google.gson.JsonArray().apply {
            add(com.google.gson.JsonObject().apply {
                addProperty("id", "call_1")
                add("function", com.google.gson.JsonObject().apply {
                    addProperty("name", "terminal")
                    addProperty("arguments", "{}")
                })
            })
        }
        val data = listOf(
            ServerMessage(role = "user", content = JsonPrimitive("run")),
            ServerMessage(role = "assistant", content = JsonPrimitive(""), toolCalls = toolCalls),
            ServerMessage(role = "tool", toolCallId = "call_1", toolName = "terminal", content = JsonPrimitive("ok")),
        )
        val entities = HistoryFolder.fold("s", data, now = 1L)

        val tools = entities[1].segments.flatMap { it.tools }
        assertTrue(tools.isNotEmpty())
        assertEquals("terminal", tools[0].name)
        assertEquals("ok", tools[0].result)
    }
}
