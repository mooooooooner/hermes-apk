import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../markdown/markdown.dart';

/// Three pulsing dots shown while a run streams.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotValue(int index) {
    // Each dot runs a 600ms up-down cycle, staggered by 160ms.
    final ms = (_controller.value * 1200 - index * 160) % 1200;
    final t = ms / 600;
    return t <= 1 ? t : 2 - t;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: 0.25 + 0.75 * _dotValue(i),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
      ],
    );
  }
}

/// Round assistant avatar: local image when configured, else the robot glyph.
class AssistantAvatar extends StatelessWidget {
  final String avatarPath;
  final double size;
  final double iconSize;

  const AssistantAvatar({
    super.key,
    required this.avatarPath,
    this.size = 34,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget child;
    if (avatarPath.trim().isNotEmpty && File(avatarPath).existsSync()) {
      child = Image.file(
        File(avatarPath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(scheme),
      );
    } else {
      child = _fallback(scheme);
    }
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _fallback(ColorScheme scheme) => Container(
        color: scheme.primary,
        alignment: Alignment.center,
        child: Icon(Icons.smart_toy_rounded,
            size: iconSize, color: scheme.onPrimary),
      );
}

/// User turn: primary-container bubble, long-press (or right click) for
/// copy / edit-resend / regenerate / delete.
class UserMessage extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onResend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const UserMessage({
    super.key,
    required this.message,
    required this.onResend,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: const [
        PopupMenuItem(value: 'copy', child: _MenuRow(Icons.copy_rounded, '复制')),
        PopupMenuItem(
            value: 'edit', child: _MenuRow(Icons.edit_rounded, '编辑重发')),
        PopupMenuItem(
            value: 'resend', child: _MenuRow(Icons.refresh_rounded, '重新生成')),
        PopupMenuItem(
            value: 'delete', child: _MenuRow(Icons.delete_rounded, '删除')),
      ],
    );
    switch (action) {
      case 'copy':
        Clipboard.setData(ClipboardData(text: message.content));
      case 'edit':
        onEdit();
      case 'resend':
        onResend();
      case 'delete':
        onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPressStart: (details) =>
            _showMenu(context, details.globalPosition),
        onSecondaryTapUp: (details) =>
            _showMenu(context, details.globalPosition),
        child: Container(
          width: MediaQuery.of(context).size.width > 640
              ? 540
              : double.infinity,
          constraints: const BoxConstraints(maxWidth: 540),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(left: 48),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.attachments.isNotEmpty) ...[
                  AttachmentGrid(attachments: message.attachments),
                  if (message.content.trim().isNotEmpty)
                    const SizedBox(height: 8),
                ],
                if (message.content.trim().isNotEmpty)
                  Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onPrimaryContainer),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

/// A render unit: either one collapsed group of tool calls or a block of
/// assistant text.
sealed class RenderBlock {
  const RenderBlock();
}

class RenderBlockTools extends RenderBlock {
  final List<ToolEvent> events;
  const RenderBlockTools(this.events);
}

class RenderBlockText extends RenderBlock {
  final String text;
  const RenderBlockText(this.text);
}

/// Flatten segments into blocks. Reasoning is intentionally dropped, and
/// consecutive tool calls (tools that are not separated by any visible text)
/// are merged into a single section so a long agent loop shows one collapsible
/// "工具调用 (N)" chip instead of one per round.
List<RenderBlock> buildRenderBlocks(List<MessageSegment> segments) {
  final out = <RenderBlock>[];
  var pendingTools = <ToolEvent>[];
  for (final segment in segments) {
    pendingTools = [...pendingTools, ...segment.tools];
    if (segment.text.trim().isNotEmpty) {
      if (pendingTools.isNotEmpty) {
        out.add(RenderBlockTools(pendingTools));
        pendingTools = [];
      }
      out.add(RenderBlockText(segment.text));
    }
  }
  if (pendingTools.isNotEmpty) out.add(RenderBlockTools(pendingTools));
  return out;
}

/// Assistant turn: avatar + name + interleaved tool/text blocks.
class AssistantMessage extends StatelessWidget {
  final ChatMessage message;
  final String assistantName;
  final String avatarPath;
  final void Function(String url)? onOpenMedia;

  const AssistantMessage({
    super.key,
    required this.message,
    required this.assistantName,
    required this.avatarPath,
    this.onOpenMedia,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isStreaming = message.status == MessageStatus.streaming ||
        message.status == MessageStatus.pending;
    final blocks = buildRenderBlocks(message.renderSegments);
    final name = assistantName.trim().isEmpty ? 'Hermes' : assistantName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssistantAvatar(avatarPath: avatarPath),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < blocks.length; index++) ...[
                    if (index > 0) const SizedBox(height: 10),
                    switch (blocks[index]) {
                      RenderBlockTools(:final events) => ToolCallsSection(
                          key: ValueKey(
                              events.first.id + events.length.toString()),
                          events: events,
                        ),
                      RenderBlockText(:final text) => MarkdownText(
                          text: text, onOpenMedia: onOpenMedia),
                    },
                  ],
                  if (isStreaming) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const TypingDots(),
                        if (!message.renderSegments
                            .any((s) => s.text.trim().isNotEmpty)) ...[
                          const SizedBox(width: 10),
                          Text(
                            _runningLabel(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
              if (message.status == MessageStatus.error) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: scheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        message.error ?? '任务失败',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ],
              if (message.status == MessageStatus.cancelled) ...[
                const SizedBox(height: 6),
                Text(
                  '已中断',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (!isStreaming && message.content.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: message.content)),
                        icon: Icon(Icons.copy_rounded,
                            size: 15, color: scheme.onSurfaceVariant),
                        tooltip: '复制',
                      ),
                    ),
                    if ((message.usage?.totalTokens ?? 0) > 0) ...[
                      const SizedBox(width: 2),
                      Text(
                        '${message.usage!.totalTokens} tokens'
                        '${message.usage!.cacheReadTokens > 0 ? " · 缓存 ${message.usage!.cacheReadTokens}" : ""}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _runningLabel() {
    for (final segment in message.renderSegments.reversed) {
      if (segment.tools.isNotEmpty) {
        return '正在执行 ${segment.tools.last.name}';
      }
    }
    return '思考中';
  }
}

/// Collapsible group of tool calls.
class ToolCallsSection extends StatefulWidget {
  final List<ToolEvent> events;

  const ToolCallsSection({super.key, required this.events});

  @override
  State<ToolCallsSection> createState() => _ToolCallsSectionState();
}

class _ToolCallsSectionState extends State<ToolCallsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.build_rounded,
                      size: 15, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '工具调用 (${widget.events.length})',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  for (var index = 0; index < widget.events.length; index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    ToolEventRow(event: widget.events[index]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ToolEventRow extends StatelessWidget {
  final ToolEvent event;

  const ToolEventRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = event.error
        ? scheme.error
        : event.status.endsWith('complete')
            ? scheme.primary
            : scheme.tertiary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.name,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              if (event.durationMs != null)
                Text(
                  '${event.durationMs}ms',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
            ],
          ),
          if ((event.preview ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.preview!,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if ((event.result ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.result!,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Attachments inside a sent user message.
class AttachmentGrid extends StatelessWidget {
  final List<Attachment> attachments;

  const AttachmentGrid({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < attachments.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          switch (attachments[index].kind) {
            AttachmentKind.image => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(attachments[index].uri),
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fileRow(
                      context, attachments[index], scheme),
                ),
              ),
            AttachmentKind.file => _fileRow(context, attachments[index], scheme),
          },
        ],
      ],
    );
  }

  Widget _fileRow(BuildContext context, Attachment attachment, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_rounded,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              attachment.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-conversation hero: big avatar + the core promise of the app.
class EmptyChatHint extends StatelessWidget {
  final String assistantName;
  final String avatarPath;

  const EmptyChatHint({
    super.key,
    required this.assistantName,
    required this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = assistantName.trim().isEmpty ? 'Hermes' : assistantName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AssistantAvatar(avatarPath: avatarPath, size: 80, iconSize: 44),
        const SizedBox(height: 14),
        Text(
          name,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '发起一个任务，然后放心关掉应用。\n完成后会通知你，回来就能看到完整结果。',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
