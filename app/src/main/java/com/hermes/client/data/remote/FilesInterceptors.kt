package com.hermes.client.data.remote

import com.hermes.client.data.prefs.SettingsRepository
import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

/**
 * Resolves every outgoing request onto the user-configured **file-service** base URL and attaches
 * the Bearer token. Mirrors [DynamicUrlInterceptor] but targets the companion file service.
 */
class FilesUrlInterceptor(
    private val settings: SettingsRepository,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val base = settings.cachedFilesBaseUrl.trim()
        if (base.isBlank()) {
            throw IOException("尚未配置文件服务地址")
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

/**
 * Adds the Bearer token only for URLs that belong to the file service. Used by Coil so Markdown
 * images served by the file service can be loaded without leaking the key to arbitrary hosts.
 */
class FilesAuthInterceptor(
    private val settings: SettingsRepository,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val base = settings.cachedFilesBaseUrl.trim().trimEnd('/')
        val key = settings.cachedApiKey.trim()
        val matches = base.isNotEmpty() && key.isNotEmpty() &&
            request.url.toString().startsWith(base)
        return if (matches) {
            chain.proceed(
                request.newBuilder().header("Authorization", "Bearer $key").build(),
            )
        } else {
            chain.proceed(request)
        }
    }
}
