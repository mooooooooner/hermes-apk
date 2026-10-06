package com.hermes.client.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hermes.client.data.prefs.AppSettings
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.data.prefs.ThemeMode
import com.hermes.client.data.remote.HermesApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed interface ConnectionTest {
    data object Idle : ConnectionTest
    data object Loading : ConnectionTest
    data class Success(val models: List<String>) : ConnectionTest
    data class Failure(val message: String) : ConnectionTest
}

@HiltViewModel
class SettingsViewModel @Inject constructor(
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

    fun setShowReasoning(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.setShowReasoning(enabled) }
    }

    fun setToolProgress(enabled: Boolean) {
        viewModelScope.launch { settingsRepository.setToolProgress(enabled) }
    }

    /** Persist the current form values first, then probe `GET /v1/models`. */
    fun testConnection(baseUrl: String, apiKey: String) {
        viewModelScope.launch {
            settingsRepository.setBaseUrl(baseUrl)
            settingsRepository.setApiKey(apiKey)
            _test.value = ConnectionTest.Loading
            runCatching { api.listModels() }
                .onSuccess { response ->
                    _test.value = ConnectionTest.Success(
                        response.data.mapNotNull { it.id },
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
