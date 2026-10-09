import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../di.dart';
import 'session_list_view_model.dart';

class SessionListRoute extends StatefulWidget {
  final void Function(String sessionId) onOpenSession;
  final VoidCallback onOpenSettings;

  const SessionListRoute({
    super.key,
    required this.onOpenSession,
    required this.onOpenSettings,
  });

  @override
  State<SessionListRoute> createState() => _SessionListRouteState();
}

class _SessionListRouteState extends State<SessionListRoute> {
  late final SessionListViewModel _viewModel = SessionListViewModel(
    sessionRepository: Di.sessionRepository,
    settingsRepository: Di.settings,
  );

  StreamSubscription<String>? _eventsSub;

  @override
  void initState() {
    super.initState();
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
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return SessionListScreen(
          sessions: _viewModel.sessions,
          configured: _viewModel.configured,
          syncing: _viewModel.syncing,
          onOpenSession: widget.onOpenSession,
          onOpenSettings: widget.onOpenSettings,
          onNewSession: () async {
            final id = await _viewModel.createSession();
            widget.onOpenSession(id);
          },
          onSync: _viewModel.syncAll,
          onRename: _viewModel.rename,
          onDelete: _viewModel.delete,
        );
      },
    );
  }
}

class SessionListScreen extends StatelessWidget {
  final List<ChatSession> sessions;
  final bool configured;
  final bool syncing;
  final ValueChanged<String> onOpenSession;
  final VoidCallback onOpenSettings;
  final VoidCallback onNewSession;
  final VoidCallback onSync;
  final void Function(String id, String title) onRename;
  final ValueChanged<String> onDelete;

  const SessionListScreen({
    super.key,
    required this.sessions,
    required this.configured,
    required this.syncing,
    required this.onOpenSession,
    required this.onOpenSettings,
    required this.onNewSession,
    required this.onSync,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'Hermes',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: syncing ? null : onSync,
            icon: syncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: '同步全部会话',
          ),
          IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded),
            tooltip: '设置',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onNewSession,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新会话'),
      ),
      body: Column(
        children: [
          if (!configured) SetupBanner(onOpenSettings: onOpenSettings),
          Expanded(
            child: sessions.isEmpty
                ? const EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 8, bottom: 96),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SessionCard(
                        session: sessions[index],
                        onOpen: () => onOpenSession(sessions[index].id),
                        onRename: () => _showRenameDialog(context, sessions[index]),
                        onDelete: () => _showDeleteDialog(context, sessions[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '会话名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onRename(session.id, controller.text);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatSession session) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除「${session.title}」？本机与服务器上的记录都会被移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onDelete(session.id);
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              '删除',
              style:
                  TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class SessionCard extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const SessionCard({
    super.key,
    required this.session,
    required this.onOpen,
    required this.onRename,
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
        PopupMenuItem(
            value: 'rename', child: _MenuRow(Icons.edit_rounded, '重命名')),
        PopupMenuItem(
            value: 'delete', child: _MenuRow(Icons.delete_rounded, '删除')),
      ],
    );
    switch (action) {
      case 'rename':
        onRename();
      case 'delete':
        onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPressStart: (details) => _showMenu(context, details.globalPosition),
      onSecondaryTapUp: (details) => _showMenu(context, details.globalPosition),
      child: Card(
        color: scheme.surfaceContainer,
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      size: 20, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (session.activeRunState != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        session.preview.isEmpty ? '尚无消息' : session.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRelativeTime(session.updatedAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showMenu(
                            context,
                            (context.findRenderObject() as RenderBox)
                                .localToGlobal(Offset.zero)),
                        icon: Icon(Icons.more_vert_rounded,
                            color: scheme.onSurfaceVariant),
                        tooltip: '更多',
                      ),
                    ),
                  ],
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

class SetupBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const SetupBanner({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '先配置服务器',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              '填写 Hermes API 的 Base URL 与 API Key 后即可开始对话。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpenSettings,
                child: const Text('前往设置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 56, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            '还没有会话',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '点击右下角开始与 Hermes 对话',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
