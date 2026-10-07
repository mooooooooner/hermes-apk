package com.hermes.client.ui.chat

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.AttachmentKind
import com.hermes.client.data.model.ChatMessage
import com.hermes.client.data.model.MessageRole
import com.hermes.client.data.remote.dto.CommandDto

@Composable
fun ChatRoute(
    onBack: () -> Unit,
    viewModel: ChatViewModel = hiltViewModel(),
) {
    val messages by viewModel.messages.collectAsStateWithLifecycle()
    val session by viewModel.session.collectAsStateWithLifecycle()
    val input by viewModel.input.collectAsStateWithLifecycle()
    val attachments by viewModel.attachments.collectAsStateWithLifecycle()
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    val isRunning by viewModel.isRunning.collectAsStateWithLifecycle()
    val commands by viewModel.commands.collectAsStateWithLifecycle()

    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(Unit) {
        viewModel.events.collect { snackbarHostState.showSnackbar(it) }
    }

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments(),
    ) { uris -> viewModel.addAttachments(uris) }

    ChatScreen(
        title = session?.title ?: "会话",
        messages = messages,
        input = input,
        attachments = attachments,
        isRunning = isRunning,
        showReasoning = settings.showReasoning,
        assistantName = settings.assistantName,
        assistantAvatarPath = settings.assistantAvatarPath,
        commands = commands,
        snackbarHostState = snackbarHostState,
        onBack = onBack,
        onInputChange = viewModel::onInputChange,
        onSend = viewModel::send,
        onStop = viewModel::stop,
        onPickFiles = { picker.launch(arrayOf("*/*")) },
        onRemoveAttachment = viewModel::removeAttachment,
        onRename = viewModel::rename,
        onRefresh = viewModel::refreshHistory,
        onResend = viewModel::resend,
        onEditAndResend = viewModel::editAndResend,
        onDelete = viewModel::deleteMessage,
        onOpenMedia = viewModel::openMedia,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    title: String,
    messages: List<ChatMessage>,
    input: String,
    attachments: List<Attachment>,
    isRunning: Boolean,
    showReasoning: Boolean,
    assistantName: String,
    assistantAvatarPath: String,
    commands: List<CommandDto>,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
    onInputChange: (String) -> Unit,
    onSend: () -> Unit,
    onStop: () -> Unit,
    onPickFiles: () -> Unit,
    onRemoveAttachment: (String) -> Unit,
    onRename: (String) -> Unit,
    onRefresh: () -> Unit,
    onResend: (Long) -> Unit,
    onEditAndResend: (Long, String) -> Unit,
    onDelete: (Long) -> Unit,
    onOpenMedia: (String) -> Unit,
) {
    var menuExpanded by remember { mutableStateOf(false) }
    var renameDialog by remember { mutableStateOf(false) }
    var editTarget by remember { mutableStateOf<ChatMessage?>(null) }

    val listState = rememberLazyListState()
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) listState.scrollToItem(messages.lastIndex)
    }
    LaunchedEffect(messages.lastOrNull()?.content?.length, messages.lastOrNull()?.reasoning?.length) {
        if (messages.isNotEmpty()) {
            val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            if (lastVisible >= messages.lastIndex - 2) listState.scrollToItem(messages.lastIndex)
        }
    }

    // Show slash-command suggestions while the user is typing a bare "/name" token.
    val commandQuery = if (input.startsWith("/") && !input.contains(' ') && !input.contains('\n')) {
        input.drop(1)
    } else {
        null
    }
    val filteredCommands = remember(commands, commandQuery) {
        if (commandQuery == null) emptyList()
        else commands.filter { it.name.contains(commandQuery, ignoreCase = true) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = title,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.titleMedium,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回")
                    }
                },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(Icons.Rounded.Refresh, contentDescription = "同步服务端历史")
                    }
                    Box {
                        IconButton(onClick = { menuExpanded = true }) {
                            Icon(Icons.Rounded.MoreVert, contentDescription = "更多")
                        }
                        DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                            DropdownMenuItem(
                                text = { Text("重命名会话") },
                                onClick = { menuExpanded = false; renameDialog = true },
                            )
                            DropdownMenuItem(
                                text = { Text("同步服务端历史") },
                                onClick = { menuExpanded = false; onRefresh() },
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding(),
        ) {
            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                if (messages.isEmpty()) {
                    EmptyChatHint(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(32.dp),
                        assistantName = assistantName,
                        avatarPath = assistantAvatarPath,
                    )
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(18.dp),
                    ) {
                        itemsIndexed(messages, key = { _, item -> item.id }) { _, message ->
                            when (message.role) {
                                MessageRole.USER -> UserMessage(
                                    message = message,
                                    onResend = { onResend(message.id) },
                                    onEdit = { editTarget = message },
                                    onDelete = { onDelete(message.id) },
                                )
                                else -> AssistantMessage(
                                    message = message,
                                    showReasoning = showReasoning,
                                    assistantName = assistantName,
                                    avatarPath = assistantAvatarPath,
                                    onOpenMedia = onOpenMedia,
                                )
                            }
                        }
                    }
                }
            }

            if (attachments.isNotEmpty()) {
                AttachmentStrip(
                    attachments = attachments,
                    onRemove = onRemoveAttachment,
                )
            }

            if (commandQuery != null && filteredCommands.isNotEmpty()) {
                CommandSuggestions(
                    commands = filteredCommands,
                    onSelect = { command ->
                        onInputChange(command.template?.takeIf { it.isNotBlank() } ?: "/${command.name}")
                    },
                )
            }

            ChatInputBar(
                input = input,
                isRunning = isRunning,
                assistantName = assistantName,
                onInputChange = onInputChange,
                onSend = onSend,
                onStop = onStop,
                onPickFiles = onPickFiles,
                onSlash = { onInputChange("/") },
            )
        }
    }

    if (renameDialog) {
        RenameChatDialog(
            initial = title,
            onDismiss = { renameDialog = false },
            onConfirm = { onRename(it); renameDialog = false },
        )
    }

    editTarget?.let { target ->
        EditMessageDialog(
            initial = target.content,
            onDismiss = { editTarget = null },
            onConfirm = { text ->
                onEditAndResend(target.id, text)
                editTarget = null
            },
        )
    }
}

@Composable
private fun AttachmentStrip(
    attachments: List<Attachment>,
    onRemove: (String) -> Unit,
) {
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(attachments, key = { it.id }) { attachment ->
            Box {
                if (attachment.kind == AttachmentKind.IMAGE) {
                    AsyncImage(
                        model = attachment.uri,
                        contentDescription = attachment.name,
                        modifier = Modifier
                            .size(64.dp)
                            .clip(MaterialTheme.shapes.small),
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .height(64.dp)
                            .clip(MaterialTheme.shapes.small)
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                            .padding(horizontal = 14.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = attachment.name,
                            style = MaterialTheme.typography.labelMedium,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.width(90.dp),
                        )
                    }
                }
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(2.dp)
                        .size(18.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surface)
                        .clickable { onRemove(attachment.id) },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Rounded.Close,
                        contentDescription = "移除",
                        modifier = Modifier.size(12.dp),
                        tint = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

@Composable
private fun ChatInputBar(
    input: String,
    isRunning: Boolean,
    assistantName: String = "Hermes",
    onInputChange: (String) -> Unit,
    onSend: () -> Unit,
    onStop: () -> Unit,
    onPickFiles: () -> Unit,
    onSlash: () -> Unit,
) {
    Surface(
        color = MaterialTheme.colorScheme.background,
        tonalElevation = 0.dp,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            IconButton(onClick = onPickFiles) {
                Icon(Icons.Rounded.Add, contentDescription = "添加附件")
            }
            OutlinedTextField(
                value = input,
                onValueChange = onInputChange,
                modifier = Modifier.weight(1f),
                placeholder = { Text("给 ${assistantName.ifBlank { "Hermes" }} 发消息…") },
                maxLines = 6,
                shape = MaterialTheme.shapes.large,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default),
                trailingIcon = {
                    IconButton(onClick = onSlash) {
                        Text(
                            text = "/",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
            )
            Spacer(Modifier.width(6.dp))
            if (isRunning) {
                FilledIconButton(
                    onClick = onStop,
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                        contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    ),
                ) {
                    Icon(Icons.Rounded.Stop, contentDescription = "中断")
                }
                Spacer(Modifier.width(6.dp))
            }
            FilledIconButton(
                onClick = onSend,
                enabled = input.isNotBlank(),
            ) {
                Icon(Icons.AutoMirrored.Rounded.Send, contentDescription = "发送")
            }
        }
    }
}

@Composable
private fun CommandSuggestions(
    commands: List<CommandDto>,
    onSelect: (CommandDto) -> Unit,
) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        shape = MaterialTheme.shapes.medium,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp),
    ) {
        Column(modifier = Modifier.heightIn(max = 260.dp).verticalScroll(rememberScrollState())) {
            commands.forEach { command ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSelect(command) }
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "/${command.name}",
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(Modifier.width(10.dp))
                    Text(
                        text = command.description.orEmpty(),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun RenameChatDialog(
    initial: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var value by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("重命名会话") },
        text = {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                singleLine = true,
                label = { Text("会话名称") },
            )
        },
        confirmButton = { TextButton(onClick = { onConfirm(value) }) { Text("保存") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } },
    )
}

@Composable
private fun EditMessageDialog(
    initial: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var value by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("编辑并重发") },
        text = {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                minLines = 2,
                maxLines = 8,
            )
        },
        confirmButton = { TextButton(onClick = { onConfirm(value) }) { Text("重发") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } },
    )
}
