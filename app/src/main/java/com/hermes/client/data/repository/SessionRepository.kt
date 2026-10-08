package com.hermes.client.data.repository

import com.hermes.client.data.local.HermesDatabase
import com.hermes.client.data.local.SessionEntity
import com.hermes.client.data.model.ChatSession
import com.hermes.client.data.remote.HermesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import retrofit2.HttpException
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SessionRepository @Inject constructor(
    private val db: HermesDatabase,
    private val api: HermesApi,
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

    /**
     * Delete locally *and* on the server. Returns true when the server also no longer has the
     * session (a 404 counts as success). Local data is removed regardless so the UI always reacts.
     */
    suspend fun deleteSynced(id: String): Boolean = withContext(Dispatchers.IO) {
        val serverGone = runCatching { api.deleteSession(id) }
            .fold(onSuccess = { true }, onFailure = { it is HttpException && it.code() == 404 })
        db.messageDao().deleteForSession(id)
        db.runDao().deleteForSession(id)
        sessionDao.delete(id)
        serverGone
    }

    /**
     * Pull every session the server knows about (including ones created outside this app) and
     * merge them into the local list. New rows are inserted; existing rows keep their local title
     * unless it is still the default, so a local rename is not clobbered. Returns the count merged.
     */
    suspend fun syncAll(): Result<Int> = withContext(Dispatchers.IO) {
        runCatching {
            val limit = 200
            var offset = 0
            var merged = 0
            val now = System.currentTimeMillis()
            while (true) {
                val page = api.listSessions(limit = limit, offset = offset)
                if (page.data.isEmpty()) break
                for (server in page.data) {
                    if (server.id.isBlank()) continue
                    // Internal sub-agent / hidden sessions are not user conversations.
                    if (server.hidden || server.isInternalChild || !server.parentSessionId.isNullOrBlank()) continue
                    val startedAt = ((server.startedAt ?: 0.0) * 1000).toLong().takeIf { it > 0 } ?: now
                    val lastActive = ((server.lastActive ?: server.startedAt ?: 0.0) * 1000).toLong()
                        .takeIf { it > 0 } ?: startedAt
                    val serverTitle = server.title?.trim().orEmpty().ifBlank { "新会话" }
                    val preview = server.preview?.trim().orEmpty()
                    val existing = sessionDao.get(server.id)
                    if (existing == null) {
                        sessionDao.upsert(
                            SessionEntity(
                                id = server.id,
                                title = serverTitle,
                                createdAt = startedAt,
                                updatedAt = lastActive,
                                preview = preview.take(120),
                            ),
                        )
                    } else {
                        val title = if (existing.title.isBlank() || existing.title == "新会话") {
                            serverTitle
                        } else {
                            existing.title
                        }
                        sessionDao.updateMeta(
                            id = server.id,
                            title = title,
                            updatedAt = maxOf(existing.updatedAt, lastActive),
                            preview = (preview.ifBlank { existing.preview }).take(120),
                        )
                    }
                    merged++
                }
                if (!page.hasMore) break
                offset += limit
            }
            merged
        }
    }

    suspend fun touchPreview(id: String, preview: String) {
        sessionDao.touch(id, System.currentTimeMillis(), preview.take(120))
    }
}
