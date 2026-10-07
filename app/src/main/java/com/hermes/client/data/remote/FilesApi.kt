package com.hermes.client.data.remote

import com.hermes.client.data.remote.dto.CommandDto
import com.hermes.client.data.remote.dto.UploadedFileDto
import okhttp3.MultipartBody
import okhttp3.ResponseBody
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Streaming

/**
 * Companion file service (bridges files/images between the app and the Hermes server).
 *
 * The real base URL is injected per request by [FilesUrlInterceptor], so paths are relative to
 * whatever file-service base URL the user configured (or the one derived from the API base URL).
 */
interface FilesApi {

    @GET("commands")
    suspend fun commands(): List<CommandDto>

    @Multipart
    @POST("upload")
    suspend fun upload(@Part file: MultipartBody.Part): UploadedFileDto

    @Streaming
    @GET("files/{id}")
    suspend fun download(@Path("id") id: String): ResponseBody
}
