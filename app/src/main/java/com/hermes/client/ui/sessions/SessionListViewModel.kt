package com.hermes.client.ui.sessions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hermes.client.data.model.ChatSession
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.data.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SessionListViewModel @Inject constructor(
    private val sessionRepository: SessionRepository,
    settingsRepository: SettingsRepository,
) : ViewModel() {

    val sessions: StateFlow<List<ChatSession>> = sessionRepository.observeSessions()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val configured: StateFlow<Boolean> = settingsRepository.settings
        .map { it.isConfigured }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), true)

    fun createSession(onCreated: (String) -> Unit) {
        viewModelScope.launch { onCreated(sessionRepository.create()) }
    }

    fun rename(id: String, title: String) {
        viewModelScope.launch { sessionRepository.rename(id, title) }
    }

    fun delete(id: String) {
        viewModelScope.launch { sessionRepository.delete(id) }
    }
}
