package com.hermes.client.ui.chat

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.SmartToy
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.hermes.client.data.model.Attachment
import com.hermes.client.data.model.AttachmentKind
import com.hermes.client.data.model.ChatMessage
import com.hermes.client.data.model.MessageSegment
import com.hermes.client.data.model.MessageStatus
import com.hermes.client.data.model.ToolEvent
import com.hermes.client.ui.markdown.MarkdownText

@Composable
fun TypingDots(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "typing")
    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
        repeat(3) { index ->
            val alpha by transition.animateFloat(
                initialValue = 0.25f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(durationMillis = 600, delayMillis = index * 160),
                    repeatMode = RepeatMode.Reverse,
                ),
                label = "dot$index",
            )
            Box(
                modifier = Modifier
                    .padding(horizontal = 2.dp)
                    .size(7.dp)
                    .alpha(alpha)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary),
            )
        }
    }
}

@Composable
fun AssistantAvatar(
    avatarPath: String,
    size: Dp = 34.dp,
    iconSize: Dp = 20.dp,
) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primary),
        contentAlignment = Alignment.Center,
    ) {
        if (avatarPath.isNotBlank()) {
            AsyncImage(
                model = java.io.File(avatarPath),
                contentDescription = null,
                modifier = Modifier
                    .size(size)
                    .clip(CircleShape),
                contentScale = ContentScale.Crop,
            )
        } else {
            Icon(
                Icons.Rounded.SmartToy,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onPrimary,
                modifier = Modifier.size(iconSize),
            )
        }
    }
}

@Composable
fun UserMessage(
    message: ChatMessage,
    onResend: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    var menu by remember { mutableStateOf(false) }
    val clipboard = LocalClipboardManager.current
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.End,
    ) {
        Box {
            Column(
                modifier = Modifier
                    .fillMaxWidth(0.86f)
                    .clip(
                        RoundedCornerShape(
                            topStart = 20.dp, topEnd = 20.dp, bottomStart = 20.dp, bottomEnd = 6.dp,
                        ),
                    )
                    .background(MaterialTheme.colorScheme.primaryContainer)
                    .combinedClickable(onClick = {}, onLongClick = { menu = true })
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                if (message.attachments.isNotEmpty()) {
                    AttachmentGrid(message.attachments)
                    if (message.content.isNotBlank()) Spacer(Modifier.height(8.dp))
                }
                if (message.content.isNotBlank()) {
                    Text(
                        text = message.content,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
            }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(
                    text = { Text("复制") },
                    leadingIcon = { Icon(Icons.Rounded.ContentCopy, null) },
                    onClick = {
                        clipboard.setText(AnnotatedString(message.content))
                        menu = false
                    },
                )
                DropdownMenuItem(
                    text = { Text("编辑重发") },
                    leadingIcon = { Icon(Icons.Rounded.Edit, null) },
                    onClick = { menu = false; onEdit() },
                )
                DropdownMenuItem(
                    text = { Text("重新生成") },
                    leadingIcon = { Icon(Icons.Rounded.Refresh, null) },
                    onClick = { menu = false; onResend() },
                )
                DropdownMenuItem(
                    text = { Text("删除") },
                    leadingIcon = { Icon(Icons.Rounded.Delete, null) },
                    onClick = { menu = false; onDelete() },
                )
            }
        }
    }
}

/** A render unit: either one collapsed group of tool calls or a block of assistant text. */
private sealed interface RenderBlock {
    data class Tools(val events: List<ToolEvent>) : RenderBlock
    data class Text(val text: String) : RenderBlock
}

/**
 * Flatten segments into blocks. Reasoning is intentionally dropped, and consecutive tool calls
 * (tools that are not separated by any visible text) are merged into a single section so a long
 * agent loop shows one collapsible "工具调用 (N)" chip instead of one per round.
 */
private fun buildRenderBlocks(segments: List<MessageSegment>): List<RenderBlock> {
    val out = ArrayList<RenderBlock>()
    val pendingTools = ArrayList<ToolEvent>()
    segments.forEach { segment ->
        pendingTools.addAll(segment.tools)
        if (segment.text.isNotBlank()) {
            if (pendingTools.isNotEmpty()) {
                out.add(RenderBlock.Tools(pendingTools.toList()))
                pendingTools.clear()
            }
            out.add(RenderBlock.Text(segment.text))
        }
    }
    if (pendingTools.isNotEmpty()) out.add(RenderBlock.Tools(pendingTools.toList()))
    return out
}

@Composable
fun AssistantMessage(
    message: ChatMessage,
    assistantName: String = "Hermes",
    avatarPath: String = "",
    onOpenMedia: ((String) -> Unit)? = null,
) {
    val clipboard = LocalClipboardManager.current
    val isStreaming = message.status == MessageStatus.STREAMING || message.status == MessageStatus.PENDING
    val blocks = buildRenderBlocks(message.renderSegments)

    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        AssistantAvatar(avatarPath = avatarPath)
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = assistantName.ifBlank { "Hermes" },
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(6.dp))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                blocks.forEachIndexed { index, block ->
                    when (block) {
                        is RenderBlock.Tools -> key(block.events.firstOrNull()?.id ?: "tools-$index") {
                            ToolCallsSection(block.events)
                        }
                        is RenderBlock.Text -> MarkdownText(text = block.text, onOpenMedia = onOpenMedia)
                    }
                }

                if (isStreaming) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TypingDots()
                        if (message.renderSegments.none { it.text.isNotBlank() }) {
                            Spacer(Modifier.width(10.dp))
                            val label = message.renderSegments.lastOrNull { it.tools.isNotEmpty() }
                                ?.tools?.lastOrNull()
                                ?.let { "正在执行 ${it.name}" } ?: "思考中"
                            Text(
                                text = label,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            if (message.status == MessageStatus.ERROR) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 6.dp),
                ) {
                    Icon(
                        Icons.Rounded.ErrorOutline,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = message.error ?: "任务失败",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            if (message.status == MessageStatus.CANCELLED) {
                Text(
                    text = "已中断",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 6.dp),
                )
            }

            if (!isStreaming && message.content.isNotBlank()) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 2.dp)) {
                    IconButton(
                        onClick = { clipboard.setText(AnnotatedString(message.content)) },
                        modifier = Modifier.size(30.dp),
                    ) {
                        Icon(
                            Icons.Rounded.ContentCopy,
                            contentDescription = "复制",
                            modifier = Modifier.size(15.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    message.usage?.let { usage ->
                        if (usage.totalTokens > 0) {
                            Spacer(Modifier.width(2.dp))
                            Text(
                                text = "${usage.totalTokens} tokens" +
                                    if (usage.cacheReadTokens > 0) " · 缓存 ${usage.cacheReadTokens}" else "",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.outline,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ToolCallsSection(events: List<ToolEvent>) {
    var expanded by remember { mutableStateOf(false) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(MaterialTheme.shapes.small)
                .combinedClickable(onClick = { expanded = !expanded })
                .padding(vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Rounded.Build,
                contentDescription = null,
                modifier = Modifier.size(15.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "工具调用 (${events.size})",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            Icon(
                if (expanded) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        AnimatedVisibility(visible = expanded) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                events.forEach { event -> ToolEventRow(event) }
            }
        }
    }
}

@Composable
private fun ToolEventRow(event: ToolEvent) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.small)
            .background(MaterialTheme.colorScheme.surface)
            .padding(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .clip(CircleShape)
                    .background(
                        when {
                            event.error -> MaterialTheme.colorScheme.error
                            event.status.endsWith("complete") -> MaterialTheme.colorScheme.primary
                            else -> MaterialTheme.colorScheme.tertiary
                        },
                    ),
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = event.name,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.weight(1f),
            )
            event.durationMs?.let {
                Text(
                    text = "${it}ms",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.outline,
                )
            }
        }
        event.preview?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(6.dp))
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 6,
            )
        }
        event.result?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(6.dp))
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 8,
            )
        }
    }
}

@Composable
fun AttachmentGrid(attachments: List<Attachment>) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        attachments.forEach { attachment ->
            when (attachment.kind) {
                AttachmentKind.IMAGE -> AsyncImage(
                    model = attachment.uri,
                    contentDescription = attachment.name,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                        .clip(MaterialTheme.shapes.medium),
                )
                AttachmentKind.FILE -> Row(
                    modifier = Modifier
                        .clip(MaterialTheme.shapes.small)
                        .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.5f))
                        .padding(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Rounded.Build,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = attachment.name,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
fun EmptyChatHint(
    modifier: Modifier = Modifier,
    assistantName: String = "Hermes",
    avatarPath: String = "",
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        AssistantAvatar(avatarPath = avatarPath, size = 80.dp, iconSize = 44.dp)
        Spacer(Modifier.height(14.dp))
        Text(
            text = assistantName.ifBlank { "Hermes" },
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = "发起一个任务，然后放心关掉应用。\n完成后会通知你，回来就能看到完整结果。",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
