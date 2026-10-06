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
) {
    val isConfigured: Boolean
        get() = baseUrl.isNotBlank() && apiKey.isNotBlank()

    companion object {
        const val DEFAULT_BASE_URL = "https://test.monsoons.dev/hermes-api"
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

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val settings: Flow<AppSettings> = dataStore.data
        .catch { e -> if (e is IOException) emit(emptyPreferences()) else throw e }
        .map { prefs -> prefs.toSettings() }
        .onEach { s ->
            cachedBaseUrl = s.baseUrl
            cachedApiKey = s.apiKey
        }
        .distinctUntilChanged()

    init {
        // Keep the synchronous cache warm for interceptors / SSE.
        scope.launch { settings.collect { } }
    }

    suspend fun snapshot(): AppSettings = settings.first()

    suspend fun setBaseUrl(value: String) = dataStore.edit { it[KEY_BASE_URL] = value.trim() }

    suspend fun setApiKey(value: String) = dataStore.edit { it[KEY_API_KEY] = value.trim() }

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

    private fun Preferences.toSettings() = AppSettings(
        baseUrl = this[KEY_BASE_URL] ?: AppSettings.DEFAULT_BASE_URL,
        apiKey = this[KEY_API_KEY] ?: "",
        themeMode = runCatching { ThemeMode.valueOf(this[KEY_THEME] ?: ThemeMode.SYSTEM.name) }
            .getOrDefault(ThemeMode.SYSTEM),
        dynamicColor = this[KEY_DYNAMIC_COLOR] ?: false,
        systemInstructions = this[KEY_SYSTEM_INSTRUCTIONS] ?: "",
        showReasoning = this[KEY_SHOW_REASONING] ?: true,
        toolProgress = this[KEY_TOOL_PROGRESS] ?: true,
    )

    private companion object {
        val KEY_BASE_URL = stringPreferencesKey("base_url")
        val KEY_API_KEY = stringPreferencesKey("api_key")
        val KEY_THEME = stringPreferencesKey("theme_mode")
        val KEY_DYNAMIC_COLOR = booleanPreferencesKey("dynamic_color")
        val KEY_SYSTEM_INSTRUCTIONS = stringPreferencesKey("system_instructions")
        val KEY_SHOW_REASONING = booleanPreferencesKey("show_reasoning")
        val KEY_TOOL_PROGRESS = booleanPreferencesKey("tool_progress")
    }
}
