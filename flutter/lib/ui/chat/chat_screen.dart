import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models.dart';
import '../../data/remote/dtos.dart';
import '../../di.dart';
import 'chat_components.dart';
import 'chat_view_model.dart';
import 'voice_recorder.dart';

/// Wires the [ChatViewModel] into the widget tree (the Android app did this in
/// ChatRoute with hiltViewModel()).
class ChatRoute extends StatefulWidget {
  final String sessionId;
  final VoidCallback onBack;

  const ChatRoute({super.key, required this.sessionId, required this.onBack});

  @override
  State<ChatRoute> createState() => _ChatRouteState();
}

class _ChatRouteState extends State<ChatRoute> {
  late final ChatViewModel _viewModel = ChatViewModel(
    sessionId: widget.sessionId,
    chatRepository: Di.chatRepository,
    sessionRepository: Di.sessionRepository,
    runManager: Di.runManager,
    fileService: Di.fileService,
    settingsRepository: Di.settings,
    chatVisibility: Di.chatVisibility,
  );

  StreamSubscription<String>? _eventsSub;
  bool _isRecording = false;
  final VoiceRecorder _recorder = VoiceRecorder();

  @override
  void initState() {
    super.initState();
    // Tell RunManager which session is on screen so a run finishing in front
    // of the user does not also fire a system notification (the live UI
    // already shows the outcome).
    Di.chatVisibility.foregroundSessionId = widget.sessionId;
    _eventsSub = _viewModel.events.listen(_showSnack);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _recorder.abort();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles();
    final paths = files.map((f) => f.path).whereType<String>().toList();
    _viewModel.addAttachments(paths);
  }

  Future<void> _onVoice() async {
    if (_isRecording) {
      setState(() => _isRecording = false);
      final file = await _recorder.stop();
      if (file != null) {
        _viewModel.sendVoice(file);
      } else {
        _viewModel.notify('录音失败');
      }
      return;
    }
    var granted = await Permission.microphone.isGranted;
    if (!granted) {
      granted = (await Permission.microphone.request()).isGranted;
    }
    if (!granted) {
      _viewModel.notify('需要麦克风权限才能发语音');
      return;
    }
    final path = await _recorder.start();
    if (path != null) {
      setState(() => _isRecording = true);
    } else {
      _viewModel.notify('无法开始录音');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final settings = _viewModel.settings;
        return ChatScreen(
          title: _viewModel.session?.title ?? '会话',
          messages: _viewModel.messages,
          input: _viewModel.input,
          attachments: _viewModel.attachments,
          isRunning: _viewModel.isRunning,
          isRecording: _isRecording,
          assistantName: settings.assistantName,
          assistantAvatarPath: settings.assistantAvatarPath,
          commands: _viewModel.commands,
          onBack: widget.onBack,
          onInputChange: _viewModel.onInputChange,
          onSend: _viewModel.send,
          onStop: _viewModel.stop,
          onPickFiles: _pickFiles,
          onRemoveAttachment: _viewModel.removeAttachment,
          onRename: (title) => _viewModel.rename(title),
          onRefresh: _viewModel.refreshHistory,
          onResend: _viewModel.resend,
          onEditAndResend: _viewModel.editAndResend,
          onDelete: _viewModel.deleteMessage,
          onOpenMedia: (url, name) => _viewModel.openMedia(url, name: name),
          onVoice: _onVoice,
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String title;
  final List<ChatMessage> messages;
  final String input;
  final List<Attachment> attachments;
  final bool isRunning;
  final bool isRecording;
  final String assistantName;
  final String assistantAvatarPath;
  final List<CommandDto> commands;
  final VoidCallback onBack;
  final ValueChanged<String> onInputChange;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onPickFiles;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<String> onRename;
  final VoidCallback onRefresh;
  final ValueChanged<int> onResend;
  final void Function(int, String) onEditAndResend;
  final ValueChanged<int> onDelete;
  final void Function(String url, String? name) onOpenMedia;
  final VoidCallback onVoice;

  const ChatScreen({
    super.key,
    required this.title,
    required this.messages,
    required this.input,
    required this.attachments,
    required this.isRunning,
    required this.isRecording,
    required this.assistantName,
    required this.assistantAvatarPath,
    required this.commands,
    required this.onBack,
    required this.onInputChange,
    required this.onSend,
    required this.onStop,
    required this.onPickFiles,
    required this.onRemoveAttachment,
    required this.onRename,
    required this.onRefresh,
    required this.onResend,
    required this.onEditAndResend,
    required this.onDelete,
    required this.onOpenMedia,
    required this.onVoice,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _listController = ScrollController(keepScrollOffset: false);
  final _inputFocus = FocusNode();
  late final TextEditingController _inputController;
  var _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.input);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in sync with the view model (e.g. cleared after send or
    // replaced by a slash-command tap) without stomping an active caret.
    if (widget.input != _inputController.text) {
      _inputController.text = widget.input;
    }
    // Messages are laid out bottom-up (`reverse: true`): item 0 is the newest
    // turn and sits at the bottom. Streaming/tool-call growth therefore stays
    // pinned to the bottom instead of snapping the last message to the
    // viewport top, and scrolling up to read history is never yanked back.
    // Only an actual new turn (size change) re-anchors to the bottom.
    if (widget.messages.length != _lastMessageCount) {
      _lastMessageCount = widget.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _listController.hasClients && widget.messages.isNotEmpty) {
          _listController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    _inputFocus.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // Show slash-command suggestions while the user is typing a bare "/name"
  // token.
  String? get _commandQuery {
    final input = widget.input;
    if (input.startsWith('/') && !input.contains(' ') && !input.contains('\n')) {
      return input.substring(1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final commandQuery = _commandQuery;
    final filteredCommands = commandQuery == null
        ? const <CommandDto>[]
        : widget.commands
            .where((c) =>
                c.name.toLowerCase().contains(commandQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '返回',
        ),
        actions: [
          IconButton(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '同步服务端历史',
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  _showRenameDialog();
                case 'sync':
                  widget.onRefresh();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('重命名会话')),
              PopupMenuItem(value: 'sync', child: Text('同步服务端历史')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: EmptyChatHint(
                        assistantName: widget.assistantName,
                        avatarPath: widget.assistantAvatarPath,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _listController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final message = widget.messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: KeyedSubtree(
                          key: ValueKey(message.id),
                          child: message.role == MessageRole.user
                              ? UserMessage(
                                  message: message,
                                  onResend: () =>
                                      widget.onResend(message.id),
                                  onEdit: () => _showEditDialog(message),
                                  onDelete: () =>
                                      widget.onDelete(message.id),
                                )
                              : AssistantMessage(
                                  message: message,
                                  assistantName: widget.assistantName,
                                  avatarPath: widget.assistantAvatarPath,
                                  onOpenMedia: (url) =>
                                      widget.onOpenMedia(url, null),
                                ),
                        ),
                      );
                    },
                  ),
          ),
          if (widget.attachments.isNotEmpty)
            AttachmentStrip(
              attachments: widget.attachments,
              onRemove: widget.onRemoveAttachment,
            ),
          if (commandQuery != null && filteredCommands.isNotEmpty)
            CommandSuggestions(
              commands: filteredCommands,
              onSelect: (command) =>
                  widget.onInputChange('/${command.name}'),
            ),
          ChatInputBar(
            input: widget.input,
            isRunning: widget.isRunning,
            isRecording: widget.isRecording,
            assistantName: widget.assistantName,
            controller: _inputController,
            onInputChange: widget.onInputChange,
            onSend: widget.onSend,
            onStop: widget.onStop,
            onPickFiles: widget.onPickFiles,
            onSlash: () {
              widget.onInputChange('/');
              _inputFocus.requestFocus();
            },
            onVoice: widget.onVoice,
            focusNode: _inputFocus,
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => _TextFieldDialog(
        title: '重命名会话',
        label: '会话名称',
        initial: widget.title,
        confirmLabel: '保存',
        onConfirm: widget.onRename,
      ),
    );
  }

  Future<void> _showEditDialog(ChatMessage message) {
    return showDialog<void>(
      context: context,
      builder: (context) => _TextFieldDialog(
        title: '编辑并重发',
        initial: message.content,
        confirmLabel: '重发',
        minLines: 2,
        maxLines: 8,
        onConfirm: (text) => widget.onEditAndResend(message.id, text),
      ),
    );
  }
}

class AttachmentStrip extends StatelessWidget {
  final List<Attachment> attachments;
  final ValueChanged<String> onRemove;

  const AttachmentStrip({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return Stack(
            children: [
              if (attachment.kind == AttachmentKind.image)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(attachment.uri),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 64,
                      height: 64,
                      color: scheme.surfaceContainerHigh,
                    ),
                  ),
                )
              else
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 90,
                    child: Text(
                      attachment.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemove(attachment.id),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 12, color: scheme.onSurface),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ChatInputBar extends StatelessWidget {
  final String input;
  final bool isRunning;
  final bool isRecording;
  final String assistantName;
  final TextEditingController? controller;
  final ValueChanged<String> onInputChange;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onPickFiles;
  final VoidCallback onSlash;
  final VoidCallback onVoice;
  final FocusNode? focusNode;

  const ChatInputBar({
    super.key,
    required this.input,
    required this.isRunning,
    required this.isRecording,
    required this.assistantName,
    this.controller,
    required this.onInputChange,
    required this.onSend,
    required this.onStop,
    required this.onPickFiles,
    required this.onSlash,
    required this.onVoice,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = assistantName.trim().isEmpty ? 'Hermes' : assistantName;
    Widget trailing;
    if (isRecording) {
      trailing = IconButton.filled(
        onPressed: onVoice,
        style: IconButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
        icon: const Icon(Icons.stop_rounded),
      );
    } else if (isRunning) {
      // While a task runs the only action is interrupt — sending into the same
      // session would race the agent loop server-side.
      trailing = IconButton.filled(
        onPressed: onStop,
        style: IconButton.styleFrom(
          backgroundColor: scheme.errorContainer,
          foregroundColor: scheme.onErrorContainer,
        ),
        icon: const Icon(Icons.stop_rounded),
      );
    } else if (input.trim().isEmpty) {
      trailing = IconButton.filled(
        onPressed: onVoice,
        style: IconButton.styleFrom(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
        ),
        icon: const Icon(Icons.mic_rounded),
      );
    } else {
      trailing = IconButton.filled(
        onPressed: onSend,
        icon: const Icon(Icons.send_rounded),
      );
    }
    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isRecording,
                onChanged: onInputChange,
                maxLines: 6,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: isRecording
                      ? '录音中…点击右侧停止并发送'
                      : '给 $name 发消息…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 12),
                  prefixIcon: IconButton(
                    onPressed: onPickFiles,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: '添加附件',
                  ),
                  suffixIcon: IconButton(
                    onPressed: onSlash,
                    icon: Text(
                      '/',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    tooltip: '命令',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class CommandSuggestions extends StatelessWidget {
  final List<CommandDto> commands;
  final ValueChanged<CommandDto> onSelect;

  const CommandSuggestions({
    super.key,
    required this.commands,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final command in commands)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              onTap: () => onSelect(command),
              title: Row(
                children: [
                  Text(
                    '/${command.name}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      command.description ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// AlertDialog with a single text field (rename / edit-resend).
class _TextFieldDialog extends StatefulWidget {
  final String title;
  final String? label;
  final String initial;
  final String confirmLabel;
  final int minLines;
  final int maxLines;
  final ValueChanged<String> onConfirm;

  const _TextFieldDialog({
    required this.title,
    this.label,
    required this.initial,
    required this.confirmLabel,
    this.minLines = 1,
    this.maxLines = 1,
    required this.onConfirm,
  });

  @override
  State<_TextFieldDialog> createState() => _TextFieldDialogState();
}

class _TextFieldDialogState extends State<_TextFieldDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            widget.onConfirm(_controller.text);
            Navigator.of(context).pop();
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
