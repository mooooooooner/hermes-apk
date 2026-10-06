package com.hermes.client.data.remote

import okhttp3.HttpUrl.Companion.toHttpUrl
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Guards the single most dangerous bug in this app: the Base URL may contain a path prefix
 * (e.g. `/hermes-api`), and every request must carry only the *relative* path so the interceptor
 * prepends the prefix exactly once. A double prefix returns 404 and silently kills SSE streaming.
 */
class UrlResolverTest {

    @Test
    fun prependsBasePathExactlyOnceForRelativeRequest() {
        val resolved = UrlResolver.resolve(
            base = "https://test.monsoons.dev/hermes-api",
            requestUrl = "http://localhost/v1/runs/run_1/events".toHttpUrl(),
        )
        assertEquals(
            "https://test.monsoons.dev/hermes-api/v1/runs/run_1/events",
            resolved.toString(),
        )
    }

    @Test
    fun worksWhenBaseHasNoPath() {
        val resolved = UrlResolver.resolve(
            base = "https://host",
            requestUrl = "http://localhost/v1/models".toHttpUrl(),
        )
        assertEquals("https://host/v1/models", resolved.toString())
    }

    @Test
    fun preservesQueryParameters() {
        val resolved = UrlResolver.resolve(
            base = "https://host/hermes-api",
            requestUrl = "http://localhost/api/sessions/s1/messages?limit=500".toHttpUrl(),
        )
        assertEquals(
            "https://host/hermes-api/api/sessions/s1/messages?limit=500",
            resolved.toString(),
        )
    }
}
