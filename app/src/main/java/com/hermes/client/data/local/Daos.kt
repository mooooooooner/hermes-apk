package com.hermes.client.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface SessionDao {
    @Query("SELECT * FROM sessions ORDER BY updatedAt DESC")
    fun observeAll(): Flow<List<SessionEntity>>

    @Query("SELECT * FROM sessions WHERE id = :id LIMIT 1")
    fun observe(id: String): Flow<SessionEntity?>

    @Query("SELECT * FROM sessions WHERE id = :id LIMIT 1")
    suspend fun get(id: String): SessionEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(session: SessionEntity)

    @Query("UPDATE sessions SET title = :title, updatedAt = :updatedAt WHERE id = :id")
    suspend fun rename(id: String, title: String, updatedAt: Long)

    @Query("UPDATE sessions SET updatedAt = :updatedAt, preview = :preview WHERE id = :id")
    suspend fun touch(id: String, updatedAt: Long, preview: String)

    @Query("UPDATE sessions SET activeRunId = :runId, activeRunState = :state WHERE id = :id")
    suspend fun setActiveRun(id: String, runId: String?, state: String?)

    @Query("DELETE FROM sessions WHERE id = :id")
    suspend fun delete(id: String)
}

@Dao
interface MessageDao {
    @Query("SELECT * FROM messages WHERE sessionId = :sessionId ORDER BY seq ASC, createdAt ASC")
    fun observe(sessionId: String): Flow<List<MessageEntity>>

    @Query("SELECT * FROM messages WHERE sessionId = :sessionId ORDER BY seq ASC, createdAt ASC")
    suspend fun list(sessionId: String): List<MessageEntity>

    @Query("SELECT * FROM messages WHERE id = :id LIMIT 1")
    suspend fun get(id: Long): MessageEntity?

    @Query("SELECT MAX(seq) FROM messages WHERE sessionId = :sessionId")
    suspend fun maxSeq(sessionId: String): Int?

    @Insert
    suspend fun insert(message: MessageEntity): Long

    @Update
    suspend fun update(message: MessageEntity)

    @Query(
        "UPDATE messages SET content = :content, reasoning = :reasoning, status = :status, " +
            "toolEvents = :toolEvents, error = :error, usage = :usage, updatedAt = :updatedAt " +
            "WHERE id = :id",
    )
    suspend fun updateProgress(
        id: Long,
        content: String,
        reasoning: String,
        status: String,
        toolEvents: String,
        error: String?,
        usage: String?,
        updatedAt: Long,
    )

    @Query("UPDATE messages SET runId = :runId, status = :status WHERE id = :id")
    suspend fun bindRun(id: Long, runId: String, status: String)

    @Query("UPDATE messages SET status = :status WHERE id = :id")
    suspend fun setStatus(id: Long, status: String)

    @Query("DELETE FROM messages WHERE sessionId = :sessionId")
    suspend fun deleteForSession(sessionId: String)

    @Query("DELETE FROM messages WHERE id = :id")
    suspend fun delete(id: Long)
}

@Dao
interface RunDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(run: RunEntity)

    @Query("SELECT * FROM runs WHERE runId = :runId LIMIT 1")
    suspend fun get(runId: String): RunEntity?

    @Query("SELECT * FROM runs WHERE sessionId = :sessionId ORDER BY createdAt DESC")
    suspend fun forSession(sessionId: String): List<RunEntity>

    @Query("SELECT * FROM runs WHERE sessionId = :sessionId ORDER BY createdAt DESC")
    fun observeForSession(sessionId: String): Flow<List<RunEntity>>

    @Query("SELECT * FROM runs WHERE status NOT IN ('COMPLETED','FAILED','CANCELLED','INTERRUPTED')")
    suspend fun activeRuns(): List<RunEntity>

    @Query(
        "UPDATE runs SET status = :status, output = :output, error = :error, lastEvent = :lastEvent, " +
            "usage = :usage, updatedAt = :updatedAt WHERE runId = :runId",
    )
    suspend fun updateStatus(
        runId: String,
        status: String,
        output: String?,
        error: String?,
        lastEvent: String?,
        usage: String?,
        updatedAt: Long,
    )

    @Query("UPDATE runs SET notified = 1 WHERE runId = :runId")
    suspend fun markNotified(runId: String)

    @Query("DELETE FROM runs WHERE sessionId = :sessionId")
    suspend fun deleteForSession(sessionId: String)
}
