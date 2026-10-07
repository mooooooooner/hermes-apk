package com.hermes.client.data.local

import androidx.room.TypeConverter
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.MessageSegment
import com.hermes.client.data.model.ToolEvent
import com.hermes.client.data.model.Usage

class Converters {
    private val gson = Gson()

    @TypeConverter
    fun attachmentsToJson(value: List<Attachment>?): String =
        gson.toJson(value ?: emptyList<Attachment>())

    @TypeConverter
    fun jsonToAttachments(value: String?): List<Attachment> {
        if (value.isNullOrBlank()) return emptyList()
        return runCatching {
            val type = object : TypeToken<List<Attachment>>() {}.type
            gson.fromJson<List<Attachment>>(value, type) ?: emptyList()
        }.getOrDefault(emptyList())
    }

    @TypeConverter
    fun toolEventsToJson(value: List<ToolEvent>?): String =
        gson.toJson(value ?: emptyList<ToolEvent>())

    @TypeConverter
    fun jsonToToolEvents(value: String?): List<ToolEvent> {
        if (value.isNullOrBlank()) return emptyList()
        return runCatching {
            val type = object : TypeToken<List<ToolEvent>>() {}.type
            gson.fromJson<List<ToolEvent>>(value, type) ?: emptyList()
        }.getOrDefault(emptyList())
    }

    @TypeConverter
    fun segmentsToJson(value: List<MessageSegment>?): String =
        gson.toJson(value ?: emptyList<MessageSegment>())

    @TypeConverter
    fun jsonToSegments(value: String?): List<MessageSegment> {
        if (value.isNullOrBlank()) return emptyList()
        return runCatching {
            val type = object : TypeToken<List<MessageSegment>>() {}.type
            gson.fromJson<List<MessageSegment>>(value, type) ?: emptyList()
        }.getOrDefault(emptyList())
    }

    @TypeConverter
    fun usageToJson(value: Usage?): String? = value?.let { gson.toJson(it) }

    @TypeConverter
    fun jsonToUsage(value: String?): Usage? {
        if (value.isNullOrBlank()) return null
        return runCatching { gson.fromJson(value, Usage::class.java) }.getOrNull()
    }
}
