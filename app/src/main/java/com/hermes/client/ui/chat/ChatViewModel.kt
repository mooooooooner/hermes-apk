package com.hermes.client.ui.chat

import android.content.Context
import android.net.Uri
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.AttachmentKind
import com.hermes.client.data.model.ChatMessage
import com.hermes.client.data.model.ChatSession
import com.hermes.client.data.model.MessageStatus
import com.hermes.client.data.prefs.AppSettings
import com.hermes.client.data.prefs.SettingsRepository
import com.hermes.client.data.repository.ChatRepository
import com.hermes.client.data.repository.RunManager
import com.hermes.client.data.repository.SessionRepository
import com.hermes.client.ui.util.resolveFile
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class ChatViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    @ApplicationContext private val context: Context,
    private val chatRepository: ChatRepository,
    private val sessionRepository: SessionRepository,
    private val runManager: RunManager,
    settingsRepository: SettingsRepository,
) : ViewModel() {

    val sessionId: String = checkNotNull(savedStateHandle["sessionId"])

    val session: StateFlow<ChatSession?> = sessionRepository.observeSession(sessionId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val messages: StateFlow<List<ChatMessage>> = chatRepository.observeMessages(sessionId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val settings: StateFlow<AppSettings> = settingsRepository.settings
        .stateIn(viewModelScope, SharingStarted.Eagerly, AppSettings())

    private val _input = MutableStateFlow("")
    val input: StateFlow<String> = _input

    private val _attachments = MutableStateFlow<List<Attachment>>(emptyList())
    val attachments: StateFlow<List<Attachment>> = _attachments

    private val _events = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val events: SharedFlow<String> = _events.asSharedFlow()

    val isRunning: StateFlow<Boolean> = messages
        .map { list ->
            list.any { it.status == MessageStatus.STREAMING || it.status == MessageStatus.PENDING }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    val activeRunId: StateFlow<String?> = messages
        .map { list ->
            list.lastOrNull {
                it.status == MessageStatus.STREAMING && it.runId != null
            }?.runId
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun onInputChange(value: String) {
        _input.value = value
    }

    fun addAttachments(uris: List<Uri>) {
        if (uris.isEmpty()) return
        val picked = uris.map { uri ->
            // Best-effort: keep read access across process restarts.
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
            val file = context.resolveFile(uri, null)
            Attachment(
                id = UUID.randomUUID().toString(),
                name = file.name,
                mimeType = file.mimeType,
                size = file.size,
                uri = file.uri.toString(),
                kind = if (file.mimeType.startsWith("image/")) AttachmentKind.IMAGE else AttachmentKind.FILE,
            )
        }
        _attachments.value = _attachments.value + picked
    }

    fun removeAttachment(id: String) {
        _attachments.value = _attachments.value.filterNot { it.id == id }
    }

    fun send() {
        val text = _input.value.trim()
        val current = _attachments.value
        if (text.isEmpty() && current.isEmpty()) return
        _input.value = ""
        _attachments.value = emptyList()
        viewModelScope.launch {
            val result = chatRepository.sendMessage(sessionId, text, current)
            result.exceptionOrNull()?.let { emitError(it.message ?: "发送失败") }
        }
    }

    fun stop() {
        val runId = activeRunId.value ?: return
        viewModelScope.launch { runManager.stop(runId) }
    }

    fun rename(title: String) {
        viewModelScope.launch { sessionRepository.rename(sessionId, title) }
    }

    fun refreshHistory() {
        viewModelScope.launch {
            val result = chatRepository.fetchHistory(sessionId)
            result.fold(
                onSuccess = { _events.tryEmit(if (it == 0) "服务端暂无历史" else "已同步 $it 条历史") },
                onFailure = { emitError(it.message ?: "同步失败") },
            )
        }
    }

    fun resend(messageId: Long) {
        viewModelScope.launch {
            chatRepository.resend(messageId)
                .exceptionOrNull()?.let { emitError(it.message ?: "重发失败") }
        }
    }

    fun editAndResend(messageId: Long, text: String) {
        viewModelScope.launch {
            chatRepository.editAndResend(messageId, text)
                .exceptionOrNull()?.let { emitError(it.message ?: "重发失败") }
        }
    }

    fun deleteMessage(messageId: Long) {
        viewModelScope.launch { chatRepository.deleteMessage(messageId) }
    }

    private fun emitError(message: String) {
        _events.tryEmit(message)
    }
}
