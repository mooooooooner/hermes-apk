package com.hermes.client.data.repository

import android.content.Context
import android.net.Uri
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.data.remote.FilesApi
import com.hermes.client.data.remote.dto.CommandDto
import com.hermes.client.data.remote.dto.UploadedFileDto
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okio.BufferedSink
import okio.source
import java.io.File
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Client for the companion file service. Two directions:
 *
 *  - **user -> agent**: attachments are uploaded here; the server-local `path` is injected into the
 *    run so the agent can read the file directly.
 *  - **agent -> user**: the agent uploads via the same service; the app loads the returned URL
 *    (images inline, other files downloaded on tap).
 */
@Singleton
class FileServiceRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val api: FilesApi,
    private val settings: SettingsRepository,
) {

    /** Upload one attachment. Returns null on any failure so the caller can fall back to inlining. */
    suspend fun upload(attachment: Attachment): UploadedFileDto? = withContext(Dispatchers.IO) {
        runCatching {
            val uri = Uri.parse(attachment.uri)
            val mediaType = attachment.mimeType.ifBlank { "application/octet-stream" }
                .toMediaTypeOrNull()
            // Stream the content instead of buffering the whole file: a large video or image must
            // never sit in memory twice (bytes + encoded multipart copy).
            val body = object : RequestBody() {
                override fun contentType(): MediaType? = mediaType

                override fun contentLength(): Long = attachment.size.takeIf { it > 0 } ?: -1L

                override fun writeTo(sink: BufferedSink) {
                    val input = context.contentResolver.openInputStream(uri)
                        ?: throw IOException("无法读取 ${attachment.name}")
                    input.use { sink.writeAll(it.source()) }
                }
            }
            val part = MultipartBody.Part.createFormData(
                "file",
                attachment.name.ifBlank { "upload.bin" },
                body,
            )
            api.upload(part)
        }.getOrNull()
    }

    suspend fun commands(): List<CommandDto> = withContext(Dispatchers.IO) {
        runCatching { api.commands() }.getOrDefault(emptyList())
            .filter { it.name.isNotBlank() }
    }

    fun isFilesUrl(url: String): Boolean {
        val base = settings.cachedFilesBaseUrl.trim().trimEnd('/')
        return base.isNotEmpty() && url.startsWith(base)
    }

    fun fileId(url: String): String? {
        val marker = "/files/"
        val index = url.indexOf(marker)
        if (index < 0) return null
        return url.substring(index + marker.length)
            .substringBefore('?')
            .substringBefore('#')
            .ifBlank { null }
    }

    /** Download a file-service URL into the app cache so it can be opened/shared. */
    suspend fun downloadToCache(url: String, name: String?): File? = withContext(Dispatchers.IO) {
        runCatching {
            val id = fileId(url) ?: return@runCatching null
            val body = api.download(id)
            val safeName = (name ?: id).replace(Regex("[^A-Za-z0-9._-]"), "_").take(80)
            val dir = File(context.cacheDir, "downloads").apply {
                mkdirs()
                // Keep the cache bounded: drop anything older than a week on every download.
                val cutoff = System.currentTimeMillis() - CACHE_TTL_MS
                listFiles()?.forEach { f -> if (f.isFile && f.lastModified() < cutoff) f.delete() }
            }
            val target = File(dir, safeName)
            body.byteStream().use { input -> target.outputStream().use { input.copyTo(it) } }
            target
        }.getOrNull()
    }

    private companion object {
        const val CACHE_TTL_MS = 7L * 24 * 60 * 60 * 1000
    }
}
