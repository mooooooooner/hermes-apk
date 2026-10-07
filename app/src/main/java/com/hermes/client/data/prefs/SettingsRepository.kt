package com.hermes.client.data.prefs

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

enum class ThemeMode { SYSTEM, LIGHT, DARK }

data class AppSettings(
    val baseUrl: String = DEFAULT_BASE_URL,
    val apiKey: String = "",
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val dynamicColor: Boolean = false,
    val systemInstructions: String = "",
    val showReasoning: Boolean = true,
    val toolProgress: Boolean = true,
    /** Display name of the assistant inside a conversation (local only). */
    val assistantName: String = "Hermes",
    /** Absolute path of the locally stored assistant avatar, or blank for the default icon. */
    val assistantAvatarPath: String = "",
    /** Base URL of the companion file service. Blank means "derive from [baseUrl]". */
    val filesBaseUrl: String = "",
) {
    val isConfigured: Boolean
        get() = baseUrl.isNotBlank() && apiKey.isNotBlank()

    /** Effective file-service base URL (explicit override, else derived from [baseUrl]). */
    val effectiveFilesBaseUrl: String
        get() = filesBaseUrl.trim().trimEnd('/').ifBlank { deriveFilesBaseUrl(baseUrl) }

    companion object {
        const val DEFAULT_BASE_URL = "https://test.monsoons.dev/hermes-api"

        /**
         * Given an API base URL, guess the companion file-service base URL. The server exposes
         * `<origin>/hermes-api` and `<origin>/hermes-files`, so we swap that suffix; otherwise we
         * append `/hermes-files`.
         */
        fun deriveFilesBaseUrl(baseUrl: String): String {
            val trimmed = baseUrl.trim().trimEnd('/')
            if (trimmed.isBlank()) return ""
            for (suffix in listOf("/hermes-api", "/api")) {
                if (trimmed.endsWith(suffix)) {
                    return trimmed.removeSuffix(suffix) + "/hermes-files"
                }
            }
            return trimmed + "/hermes-files"
        }
    }
}

private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "hermes_settings",
)

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext context: Context,
) {
    private val dataStore = context.settingsDataStore

    /** In-memory mirrors so synchronous OkHttp interceptors can read the current config. */
    @Volatile
    var cachedBaseUrl: String = AppSettings.DEFAULT_BASE_URL
        private set

    @Volatile
    var cachedApiKey: String = ""
        private set

    /** Auth header for the companion file service (and Coil image loads). */
    @Volatile
    var cachedFilesBaseUrl: String = AppSettings.deriveFilesBaseUrl(AppSettings.DEFAULT_BASE_URL)
        private set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val settings: Flow<AppSettings> = dataStore.data
        .catch { e -> if (e is IOException) emit(emptyPreferences()) else throw e }
        .map { prefs -> prefs.toSettings() }
        .onEach { s ->
            cachedBaseUrl = s.baseUrl
            cachedApiKey = s.apiKey
            cachedFilesBaseUrl = s.effectiveFilesBaseUrl
        }
        .distinctUntilChanged()

    init {
        // Keep the synchronous cache warm for interceptors / SSE.
        scope.launch { settings.collect { } }
    }

    suspend fun snapshot(): AppSettings = settings.first()

    // Update the volatile mirrors synchronously as well, so a request issued right after saving
    // (e.g. "测试连接") can't race the DataStore -> flow -> cache round trip.
    suspend fun setBaseUrl(value: String) {
        val trimmed = value.trim()
        dataStore.edit { it[KEY_BASE_URL] = trimmed }
        cachedBaseUrl = trimmed
        val explicit = dataStore.data.first()[KEY_FILES_BASE_URL]?.trim().orEmpty()
        cachedFilesBaseUrl = explicit.ifBlank { AppSettings.deriveFilesBaseUrl(trimmed) }
    }

    suspend fun setApiKey(value: String) {
        val trimmed = value.trim()
        dataStore.edit { it[KEY_API_KEY] = trimmed }
        cachedApiKey = trimmed
    }

    suspend fun setThemeMode(value: ThemeMode) =
        dataStore.edit { it[KEY_THEME] = value.name }

    suspend fun setDynamicColor(value: Boolean) =
        dataStore.edit { it[KEY_DYNAMIC_COLOR] = value }

    suspend fun setSystemInstructions(value: String) =
        dataStore.edit { it[KEY_SYSTEM_INSTRUCTIONS] = value }

    suspend fun setShowReasoning(value: Boolean) =
        dataStore.edit { it[KEY_SHOW_REASONING] = value }

    suspend fun setToolProgress(value: Boolean) =
        dataStore.edit { it[KEY_TOOL_PROGRESS] = value }

    suspend fun setAssistantName(value: String) =
        dataStore.edit { it[KEY_ASSISTANT_NAME] = value.trim() }

    suspend fun setAssistantAvatarPath(value: String) =
        dataStore.edit { it[KEY_ASSISTANT_AVATAR] = value.trim() }

    suspend fun setFilesBaseUrl(value: String) {
        val trimmed = value.trim()
        dataStore.edit { it[KEY_FILES_BASE_URL] = trimmed }
        cachedFilesBaseUrl = trimmed.ifBlank { AppSettings.deriveFilesBaseUrl(cachedBaseUrl) }
    }

    private fun Preferences.toSettings() = AppSettings(
        baseUrl = this[KEY_BASE_URL] ?: AppSettings.DEFAULT_BASE_URL,
        apiKey = this[KEY_API_KEY] ?: "",
        themeMode = runCatching { ThemeMode.valueOf(this[KEY_THEME] ?: ThemeMode.SYSTEM.name) }
            .getOrDefault(ThemeMode.SYSTEM),
        dynamicColor = this[KEY_DYNAMIC_COLOR] ?: false,
        systemInstructions = this[KEY_SYSTEM_INSTRUCTIONS] ?: "",
        showReasoning = this[KEY_SHOW_REASONING] ?: true,
        toolProgress = this[KEY_TOOL_PROGRESS] ?: true,
        assistantName = this[KEY_ASSISTANT_NAME]?.takeIf { it.isNotBlank() } ?: "Hermes",
        assistantAvatarPath = this[KEY_ASSISTANT_AVATAR] ?: "",
        filesBaseUrl = this[KEY_FILES_BASE_URL] ?: "",
    )

    private companion object {
        val KEY_BASE_URL = stringPreferencesKey("base_url")
        val KEY_API_KEY = stringPreferencesKey("api_key")
        val KEY_THEME = stringPreferencesKey("theme_mode")
        val KEY_DYNAMIC_COLOR = booleanPreferencesKey("dynamic_color")
        val KEY_SYSTEM_INSTRUCTIONS = stringPreferencesKey("system_instructions")
        val KEY_SHOW_REASONING = booleanPreferencesKey("show_reasoning")
        val KEY_TOOL_PROGRESS = booleanPreferencesKey("tool_progress")
        val KEY_ASSISTANT_NAME = stringPreferencesKey("assistant_name")
        val KEY_ASSISTANT_AVATAR = stringPreferencesKey("assistant_avatar_path")
        val KEY_FILES_BASE_URL = stringPreferencesKey("files_base_url")
    }
}
