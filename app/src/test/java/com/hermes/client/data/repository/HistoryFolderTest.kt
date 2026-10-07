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
