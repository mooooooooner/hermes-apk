package com.hermes.client.ui.chat

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
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
import com.hermes.client.data.remote.dto.CommandDto
import com.hermes.client.data.repository.ChatRepository
import com.hermes.client.data.repository.FileServiceRepository
import com.hermes.client.data.repository.RunManager
import com.hermes.client.data.repository.SessionRepository
import com.hermes.client.ui.util.resolveFile
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
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
    private val fileService: FileServiceRepository,
    settingsRepository: SettingsRepository,
) : ViewModel() {

    val sessionId: String = checkNotNull(savedStateHandle["sessionId"])

    /**
     * The in-flight send/resend coroutine. Kept so [stop] can cancel a submit that has not yet
     * produced a run id (otherwise an interrupt during the first network call would be a no-op).
     */
    private var submitJob: Job? = null

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

    private val _commands = MutableStateFlow(DEFAULT_COMMANDS)
    val commands: StateFlow<List<CommandDto>> = _commands

    private val _events = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val events: SharedFlow<String> = _events.asSharedFlow()

    val isRunning: StateFlow<Boolean> = messages
        .map { list ->
            list.any { it.status == MessageStatus.STREAMING || it.status == MessageStatus.PENDING }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    // Eagerly, because stop() reads activeRunId.value without collecting it: with
    // WhileSubscribed the upstream never starts and .value would stay null, so the
    // interrupt button would silently do nothing.
    val activeRunId: StateFlow<String?> = messages
        .map { list ->
            list.lastOrNull {
                it.status == MessageStatus.STREAMING && it.runId != null
            }?.runId
        }
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    init {
        // Slash-command list is served by the file service so it can be edited server-side.
        refreshCommands()
    }

    fun onInputChange(value: String) {
        _input.value = value
    }

    fun notify(message: String) {
        _events.tryEmit(message)
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
        launchSubmit { chatRepository.sendMessage(sessionId, text, current) }
    }

    /** Send a recorded voice note as a real audio attachment (Hermes transcribes it server-side). */
    fun sendVoice(file: java.io.File) {
        val attachment = Attachment(
            id = UUID.randomUUID().toString(),
            name = file.name,
            mimeType = "audio/mp4",
            size = file.length(),
            uri = Uri.fromFile(file).toString(),
            kind = AttachmentKind.FILE,
        )
        launchSubmit { chatRepository.sendMessage(sessionId, "🎤 语音消息", listOf(attachment)) }
    }

    fun stop() {
        val runId = activeRunId.value
        if (runId != null) {
            viewModelScope.launch { runManager.stop(runId) }
            return
        }
        // No run yet: either the first network call is still hanging or the placeholder was
        // orphaned by a crash. Cancel locally and clear it so the chat stops spinning.
        submitJob?.cancel()
        submitJob = null
        viewModelScope.launch {
            val cleared = chatRepository.cancelPending(sessionId)
            if (cleared > 0) emitError("已取消未发出的消息")
        }
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

    fun refreshCommands() {
        viewModelScope.launch {
            val remote = fileService.commands()
            if (remote.isNotEmpty()) _commands.value = remote
        }
    }

    /** Open a delivered file/image: file-service URLs are downloaded (with auth) first. */
    fun openMedia(url: String, name: String? = null) {
        viewModelScope.launch {
            if (!fileService.isFilesUrl(url)) {
                runCatching {
                    context.startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }.onFailure { emitError("无法打开链接") }
                return@launch
            }
            _events.tryEmit("正在下载文件…")
            val file = fileService.downloadToCache(url, name)
            if (file == null) {
                emitError("下载失败")
                return@launch
            }
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, context.contentResolver.getType(uri) ?: "*/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(intent, "打开文件")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            runCatching { context.startActivity(chooser) }
                .onFailure { emitError("没有可打开该文件的应用") }
        }
    }

    fun resend(messageId: Long) {
        launchSubmit { chatRepository.resend(messageId) }
    }

    fun editAndResend(messageId: Long, text: String) {
        launchSubmit { chatRepository.editAndResend(messageId, text) }
    }

    /** Run a submit suspending call and surface failures; cancellations are swallowed silently. */
    private fun launchSubmit(block: suspend () -> Result<String>) {
        submitJob?.cancel()
        submitJob = viewModelScope.launch {
            block().exceptionOrNull()?.let { emitError(it.message ?: "发送失败") }
        }
    }

    fun deleteMessage(messageId: Long) {
        viewModelScope.launch { chatRepository.deleteMessage(messageId) }
    }

    private fun emitError(message: String) {
        _events.tryEmit(message)
    }

    private companion object {
        val DEFAULT_COMMANDS = listOf(
            CommandDto(name = "help", description = "显示可用命令", template = "/help"),
            CommandDto(name = "status", description = "显示当前会话状态", template = "/status"),
        )
    }
}
