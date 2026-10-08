package com.hermes.client.ui.sessions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hermes.client.data.model.ChatSession
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.data.repository.SessionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
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

    private val _syncing = MutableStateFlow(false)
    val syncing: StateFlow<Boolean> = _syncing

    private val _events = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val events: SharedFlow<String> = _events.asSharedFlow()

    fun createSession(onCreated: (String) -> Unit) {
        viewModelScope.launch { onCreated(sessionRepository.create()) }
    }

    fun rename(id: String, title: String) {
        viewModelScope.launch { sessionRepository.rename(id, title) }
    }

    fun delete(id: String) {
        viewModelScope.launch {
            val serverGone = sessionRepository.deleteSynced(id)
            if (!serverGone) _events.tryEmit("已从本机删除，但服务端删除失败")
        }
    }

    /** Pull every session the server knows about, including ones created outside this app. */
    fun syncAll() {
        if (_syncing.value) return
        viewModelScope.launch {
            _syncing.value = true
            try {
                sessionRepository.syncAll().fold(
                    onSuccess = { count ->
                        _events.tryEmit(if (count == 0) "没有可同步的会话" else "已同步 $count 个会话")
                    },
                    onFailure = { error ->
                        _events.tryEmit("同步失败：${error.message ?: "网络错误"}")
                    },
                )
            } finally {
                _syncing.value = false
            }
        }
    }
}
