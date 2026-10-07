package com.hermes.client.data.prefs

import org.junit.Assert.assertEquals
import org.junit.Test

class FilesBaseUrlTest {

    @Test
    fun swapsHermesApiSuffix() {
        assertEquals(
            "https://host/hermes-files",
            AppSettings.deriveFilesBaseUrl("https://host/hermes-api"),
        )
    }

    @Test
    fun swapsTrailingApiSuffix() {
        assertEquals(
            "https://host/hermes-files",
            AppSettings.deriveFilesBaseUrl("https://host/api/"),
        )
    }

    @Test
    fun appendsWhenNoKnownSuffix() {
        assertEquals(
            "https://host/base/hermes-files",
            AppSettings.deriveFilesBaseUrl("https://host/base"),
        )
    }

    @Test
    fun blankStaysBlank() {
        assertEquals("", AppSettings.deriveFilesBaseUrl("  "))
    }
}
