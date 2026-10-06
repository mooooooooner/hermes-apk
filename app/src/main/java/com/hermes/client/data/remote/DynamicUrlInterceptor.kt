package com.hermes.client.data.remote

import com.hermes.client.data.prefs.SettingsRepository
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

/**
 * Rewrites every outgoing request onto the user-configured Base URL (which may include a path
 * prefix) and attaches the Bearer token. This lets the user change server settings at runtime
 * without rebuilding Retrofit.
 */
class DynamicUrlInterceptor(
    private val settings: SettingsRepository,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val base = settings.cachedBaseUrl.trim()
        if (base.isBlank()) {
            throw IOException("尚未配置服务器地址，请先在设置中填写 Base URL")
        }
        val baseUrl = base.trimEnd('/').toHttpUrlOrNull()
            ?: throw IOException("服务器地址无效: $base")

        // Preserve the path configured by the interface (e.g. v1/models) plus any query params.
        val relativePath = original.url.encodedPath.trimStart('/')
        val newUrl = baseUrl.newBuilder()
            .apply {
                if (relativePath.isNotEmpty()) {
                    addPathSegments(relativePath)
                }
                original.url.query?.let { query(it) }
            }
            .build()

        val builder = original.newBuilder().url(newUrl)
        val key = settings.cachedApiKey.trim()
        if (key.isNotEmpty() && original.header("Authorization") == null) {
            builder.header("Authorization", "Bearer $key")
        }
        return chain.proceed(builder.build())
    }
}
