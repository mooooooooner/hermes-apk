package com.hermes.client.data.repository

import com.hermes.client.data.local.HermesDatabase
import com.hermes.client.data.local.SessionEntity
import com.hermes.client.data.model.ChatSession
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SessionRepository @Inject constructor(
    private val db: HermesDatabase,
) {
    private val sessionDao get() = db.sessionDao()

    fun observeSessions(): Flow<List<ChatSession>> =
        sessionDao.observeAll().map { list -> list.map { it.toDomain() } }

    fun observeSession(id: String): Flow<ChatSession?> =
        sessionDao.observe(id).map { it?.toDomain() }

    suspend fun get(id: String): ChatSession? = sessionDao.get(id)?.toDomain()

    suspend fun create(title: String = "新会话"): String {
        val now = System.currentTimeMillis()
        val id = "hm-" + UUID.randomUUID().toString().replace("-", "").take(24)
        sessionDao.upsert(
            SessionEntity(id = id, title = title, createdAt = now, updatedAt = now),
        )
        return id
    }

    suspend fun ensure(id: String): String {
        if (sessionDao.get(id) == null) {
            val now = System.currentTimeMillis()
            sessionDao.upsert(SessionEntity(id = id, title = "新会话", createdAt = now, updatedAt = now))
        }
        return id
    }

    suspend fun rename(id: String, title: String) {
        val clean = title.trim().ifBlank { "未命名会话" }
        sessionDao.rename(id, clean, System.currentTimeMillis())
    }

    suspend fun delete(id: String) {
        db.messageDao().deleteForSession(id)
        db.runDao().deleteForSession(id)
        sessionDao.delete(id)
    }

    suspend fun touchPreview(id: String, preview: String) {
        sessionDao.touch(id, System.currentTimeMillis(), preview.take(120))
    }
}
