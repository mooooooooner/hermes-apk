package com.hermes.client.data.remote

import com.hermes.client.data.remote.dto.Capabilities
import com.hermes.client.data.remote.dto.HealthResponse
import com.hermes.client.data.remote.dto.ModelsResponse
import com.hermes.client.data.remote.dto.RunCreatedDto
import com.hermes.client.data.remote.dto.RunRequest
import com.hermes.client.data.remote.dto.RunStatusDto
import com.hermes.client.data.remote.dto.SessionMessagesResponse
import com.hermes.client.data.remote.dto.ServerSessionsResponse
import com.hermes.client.data.remote.dto.SteerRequest
import com.google.gson.JsonElement
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Hermes OpenAI-compatible API.
 *
 * The real base URL is injected per request by [DynamicUrlInterceptor], so the paths here are
 * relative to whatever Base URL the user configured (it may contain a path prefix like
 * `https://host/hermes-api`).
 */
interface HermesApi {

    @GET("health")
    suspend fun health(): HealthResponse

    @GET("v1/models")
    suspend fun listModels(): ModelsResponse

    @GET("v1/capabilities")
    suspend fun capabilities(): Capabilities

    @POST("v1/runs")
    suspend fun createRun(
        @Body body: RunRequest,
        @Header("Idempotency-Key") idempotencyKey: String? = null,
    ): RunCreatedDto

    @GET("v1/runs/{runId}")
    suspend fun runStatus(@Path("runId") runId: String): RunStatusDto

    @POST("v1/runs/{runId}/stop")
    suspend fun stopRun(@Path("runId") runId: String): JsonElement

    @POST("v1/runs/{runId}/steer")
    suspend fun steerRun(@Path("runId") runId: String, @Body body: SteerRequest): JsonElement

    @GET("api/sessions/{sessionId}/messages")
    suspend fun sessionMessages(
        @Path("sessionId") sessionId: String,
        @Query("limit") limit: Int = 500,
    ): SessionMessagesResponse

    /** List every session known to the server (including ones created outside this app). */
    @GET("api/sessions")
    suspend fun listSessions(
        @Query("limit") limit: Int = 200,
        @Query("offset") offset: Int = 0,
    ): ServerSessionsResponse

    /** Delete a session on the server so it disappears for every client. */
    @DELETE("api/sessions/{sessionId}")
    suspend fun deleteSession(@Path("sessionId") sessionId: String): JsonElement
}
