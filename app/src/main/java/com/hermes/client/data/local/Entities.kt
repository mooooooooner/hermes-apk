package com.hermes.client.data.local

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.MessageSegment
import com.hermes.client.data.model.MessageStatus
import com.hermes.client.data.model.ToolEvent
import com.hermes.client.data.model.Usage

@Entity(tableName = "sessions")
data class SessionEntity(
    @PrimaryKey val id: String,
    val title: String,
    val createdAt: Long,
    val updatedAt: Long,
    val preview: String = "",
    val activeRunId: String? = null,
    val activeRunState: String? = null,
)

@Entity(
    tableName = "messages",
    indices = [Index("sessionId"), Index("runId")],
)
data class MessageEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val sessionId: String,
    val role: String,
    val content: String = "",
    val reasoning: String = "",
    val status: String = MessageStatus.COMPLETE.name,
    val runId: String? = null,
    val seq: Int = 0,
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
    val attachments: List<Attachment> = emptyList(),
    val toolEvents: List<ToolEvent> = emptyList(),
    val segments: List<MessageSegment> = emptyList(),
    val error: String? = null,
    val usage: Usage? = null,
    val serverId: Long? = null,
)

@Entity(tableName = "runs")
data class RunEntity(
    @PrimaryKey val runId: String,
    val sessionId: String,
    val userMessageId: Long? = null,
    val assistantMessageId: Long? = null,
    val status: String,
    val output: String? = null,
    val error: String? = null,
    val lastEvent: String? = null,
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
    val notified: Boolean = false,
    val usage: Usage? = null,
)
