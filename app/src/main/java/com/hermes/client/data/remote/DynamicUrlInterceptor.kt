package com.hermes.client.data.remote

import com.hermes.client.data.prefs.SettingsRepository
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

/**
 * Rewrites every outgoing request onto the user-configured Base URL (which may include a path
 * prefix) and attaches the Bearer token. This lets the user change server settings at runtime
 * without rebuilding Retrofit.
 *
 * Contract: callers must build requests with only the **relative** path (Retrofit's
 * `@GET("v1/models")`, or a placeholder host like `http://localhost/...`). The configured base
 * path is then prepended exactly once. Passing an absolute URL that already contains the base
 * path would duplicate it (e.g. `/hermes-api/hermes-api/...` -> 404).
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
        val newUrl = UrlResolver.resolve(base, original.url)

        val builder = original.newBuilder().url(newUrl)
        val key = settings.cachedApiKey.trim()
        if (key.isNotEmpty() && original.header("Authorization") == null) {
            builder.header("Authorization", "Bearer $key")
        }
        return chain.proceed(builder.build())
    }
}

/** Pure URL join used by [DynamicUrlInterceptor]; unit-tested to prevent double path prefixes. */
object UrlResolver {
    fun resolve(base: String, requestUrl: HttpUrl): HttpUrl {
        val baseUrl = base.trim().trimEnd('/').toHttpUrlOrNull()
            ?: throw IOException("服务器地址无效: $base")
        val relativePath = requestUrl.encodedPath.trimStart('/')
        return baseUrl.newBuilder()
            .apply {
                if (relativePath.isNotEmpty()) addPathSegments(relativePath)
                requestUrl.query?.let { query(it) }
            }
            .build()
    }
}
