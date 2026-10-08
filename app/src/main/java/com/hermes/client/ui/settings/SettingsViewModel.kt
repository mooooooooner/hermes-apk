package com.hermes.client.ui.settings

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hermes.client.data.prefs.AppSettings
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.data.prefs.ThemeMode
import com.hermes.client.data.remote.HermesApi
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import javax.inject.Inject

sealed interface ConnectionTest {
    data object Idle : ConnectionTest
    data object Loading : ConnectionTest
    data class Success(
        val models: List<String>,
        /** True when the configured Base URL uses plaintext http://. */
        val insecureUrl: Boolean = false,
    ) : ConnectionTest
    data class Failure(val message: String) : ConnectionTest
}

@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val settingsRepository: SettingsRepository,
    private val api: HermesApi,
) : ViewModel() {

    val settings: StateFlow<AppSettings> = settingsRepository.settings.stateIn(
        viewModelScope, SharingStarted.Eagerly, AppSettings(),
    )

    private val _test = MutableStateFlow<ConnectionTest>(ConnectionTest.Idle)
    val test: StateFlow<ConnectionTest> = _test.asStateFlow()

    fun saveConnection(baseUrl: String, apiKey: String) {
        viewModelScope.launch {
            settingsRepository.setBaseUrl(baseUrl)
            settingsRepository.setApiKey(apiKey)
        }
    }

    fun saveSystemInstructions(value: String) {
        viewModelScope.launch { settingsRepository.setSystemInstructions(value) }
    }

    fun setThemeMode(mode: ThemeMode) {
        viewModelScope.launch { settingsRepository.setThemeMode(mode) }
    }

    fun setDynamicColor(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.setDynamicColor(enabled) }
    }

    fun setToolProgress(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.setToolProgress(enabled) }
    }

    fun setAssistantName(name: String) {
        viewModelScope.launch { settingsRepository.setAssistantName(name) }
    }

    fun setFilesBaseUrl(value: String) {
        viewModelScope.launch { settingsRepository.setFilesBaseUrl(value) }
    }

    /** Copy the picked image into app storage so it survives content-URI revocation. */
    fun setAssistantAvatar(uri: Uri) {
        viewModelScope.launch {
            val path = withContext(Dispatchers.IO) {
                runCatching {
                    val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        ?: return@runCatching null
                    val file = File(context.filesDir, "assistant_avatar_${System.currentTimeMillis()}.img")
                    file.writeBytes(bytes)
                    file.absolutePath
                }.getOrNull()
            } ?: return@launch
            settingsRepository.setAssistantAvatarPath(path)
        }
    }

    fun clearAssistantAvatar() {
        viewModelScope.launch { settingsRepository.setAssistantAvatarPath("") }
    }

    /** Persist the current form values first, then probe `GET /v1/models`. */
    fun testConnection(baseUrl: String, apiKey: String) {
        viewModelScope.launch {
            settingsRepository.setBaseUrl(baseUrl)
            settingsRepository.setApiKey(apiKey)
            _test.value = ConnectionTest.Loading
            val insecure = baseUrl.trim().startsWith("http://", ignoreCase = true)
            runCatching { api.listModels() }
                .onSuccess { response ->
                    _test.value = ConnectionTest.Success(
                        models = response.data.mapNotNull { it.id },
                        insecureUrl = insecure,
                    )
                }
                .onFailure { error ->
                    _test.value = ConnectionTest.Failure(error.message ?: "连接失败")
                }
        }
    }

    fun clearTest() {
        _test.value = ConnectionTest.Idle
    }
}
