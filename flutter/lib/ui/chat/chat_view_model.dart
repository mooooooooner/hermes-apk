import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/visibility.dart';
import '../../data/models.dart';
import '../../data/prefs/settings_repository.dart';
import '../../data/remote/dtos.dart';
import '../../data/repository/chat_repository.dart';
import '../../data/repository/file_service_repository.dart';
import '../../data/repository/run_manager.dart';
import '../../data/repository/session_repository.dart';

/// Chat screen state holder, ported from the Android ViewModel. Exposed to the
/// UI through [ChangeNotifier] / [ListenableBuilder].
class ChatViewModel extends ChangeNotifier {
  final String sessionId;
  final ChatRepository chatRepository;
  final SessionRepository sessionRepository;
  final RunManager runManager;
  final FileServiceRepository fileService;
  final SettingsRepository settingsRepository;
  final ChatVisibility chatVisibility;

  ChatViewModel({
    required this.sessionId,
    required this.chatRepository,
    required this.sessionRepository,
    required this.runManager,
    required this.fileService,
    required this.settingsRepository,
    required this.chatVisibility,
  }) {
    _subs.add(sessionRepository.observeSession(sessionId).listen((s) {
      session = s;
      notifyListeners();
    }));
    _subs.add(chatRepository.observeMessages(sessionId).listen((list) {
      messages = list;
      isRunning = list.any((m) =>
          m.status == MessageStatus.streaming ||
          m.status == MessageStatus.pending);
      activeRunId = null;
      for (final m in list) {
        if (m.status == MessageStatus.streaming && m.runId != null) {
          activeRunId = m.runId;
          break;
        }
      }
      notifyListeners();
    }));
    _subs.add(settingsRepository.settings.listen((s) {
      settings = s;
      notifyListeners();
    }));
    // Slash-command list is served by the file service so it can be edited
    // server-side.
    refreshCommands();
  }

  final _subs = <StreamSubscription<dynamic>>[];
  final _events = StreamController<String>.broadcast();

  /// One-shot messages (errors + confirmations) for the SnackBar.
  Stream<String> get events => _events.stream;

  ChatSession? session;
  List<ChatMessage> messages = const [];
  AppSettings settings = const AppSettings();
  String input = '';
  List<Attachment> attachments = const [];
  List<CommandDto> commands = defaultCommands;
  bool isRunning = false;
  String? activeRunId;

  static const defaultCommands = [
    CommandDto(name: 'help', description: '显示可用命令'),
    CommandDto(name: 'status', description: '显示当前会话状态'),
  ];

  void onInputChange(String value) {
    input = value;
    notifyListeners();
  }

  void notify(String message) {
    _events.add(message);
  }

  /// Turn picked file paths into attachments (path-based on both platforms).
  void addAttachments(List<String> paths) {
    if (paths.isEmpty) return;
    const uuid = Uuid();
    final picked = <Attachment>[];
    for (final path in paths) {
      final file = File(path);
      final name = p.basename(path);
      final mime = guessMime(name);
      picked.add(Attachment(
        id: uuid.v4(),
        name: name,
        mimeType: mime,
        size: file.existsSync() ? file.lengthSync() : 0,
        uri: path,
        kind: mime.startsWith('image/') ? AttachmentKind.image : AttachmentKind.file,
      ));
    }
    attachments = [...attachments, ...picked];
    notifyListeners();
  }

  void removeAttachment(String id) {
    attachments = attachments.where((a) => a.id != id).toList();
    notifyListeners();
  }

  void send() {
    // One run at a time per session: the server steps on the same agent loop
    // otherwise.
    if (isRunning) {
      _emitError('已有任务进行中，请先停止再发送');
      return;
    }
    final text = input.trim();
    final current = attachments;
    if (text.isEmpty && current.isEmpty) return;
    input = '';
    attachments = const [];
    notifyListeners();
    _launchSubmit(() => chatRepository.sendMessage(sessionId, text,
        attachments: current));
  }

  /// Send a recorded voice note as a real audio attachment (Hermes transcribes
  /// it server-side).
  void sendVoice(File file) {
    if (isRunning) {
      _emitError('已有任务进行中，请先停止再发送');
      return;
    }
    final attachment = Attachment(
      id: const Uuid().v4(),
      name: p.basename(file.path),
      mimeType: 'audio/mp4',
      size: file.existsSync() ? file.lengthSync() : 0,
      uri: file.path,
      kind: AttachmentKind.file,
    );
    _launchSubmit(() async {
      final runId = await chatRepository.sendMessage(sessionId, '🎤 语音消息',
          attachments: [attachment]);
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      return runId;
    });
  }

  void stop() {
    final runId = activeRunId;
    if (runId != null) {
      unawaited(_stopRun(runId));
      return;
    }
    unawaited(() async {
      // Mark the pending placeholder CANCELLED so the submit's post-flight
      // check sees the user's intent and stops the server-side run it just
      // created.
      final cleared = await chatRepository.cancelPending(sessionId);
      // The submit may have completed between reading activeRunId and now:
      // re-query the DB and stop whatever run actually got created.
      final lateRunId = await chatRepository.activeRunId(sessionId);
      if (lateRunId != null) {
        await _stopRun(lateRunId);
      } else if (cleared > 0) {
        _emitError('已取消未发出的消息');
      }
    }());
  }

  Future<void> _stopRun(String runId) async {
    try {
      await runManager.stop(runId);
    } catch (e) {
      _emitError('中断请求未送达：${_errorMessage(e)}（任务仍在服务端运行）');
    }
  }

  Future<void> rename(String title) => sessionRepository.rename(sessionId, title);

  void refreshHistory() {
    unawaited(() async {
      try {
        final count = await chatRepository.fetchHistory(sessionId);
        _events.add(count == 0 ? '服务端暂无历史' : '已同步 $count 条历史');
      } catch (e) {
        _emitError(_errorMessage(e));
      }
    }());
  }

  void refreshCommands() {
    unawaited(() async {
      final remote = await fileService.commands();
      if (remote.isNotEmpty) {
        commands = remote;
        notifyListeners();
      }
    }());
  }

  /// Open a delivered file/image: file-service URLs are downloaded (with auth)
  /// first, then handed to the OS.
  void openMedia(String url, {String? name}) {
    unawaited(() async {
      if (!fileService.isFilesUrl(url)) {
        try {
          await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        } catch (_) {
          _emitError('无法打开链接');
        }
        return;
      }
      _events.add('正在下载文件…');
      final file = await fileService.downloadToCache(url, name);
      if (file == null) {
        _emitError('下载失败');
        return;
      }
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _emitError('没有可打开该文件的应用');
      }
    }());
  }

  void resend(int messageId) {
    _launchSubmit(() => chatRepository.resend(messageId));
  }

  void editAndResend(int messageId, String text) {
    _launchSubmit(() => chatRepository.editAndResend(messageId, text));
  }

  /// Run a submit call and surface failures.
  void _launchSubmit(Future<String> Function() block) {
    unawaited(() async {
      try {
        await block();
      } catch (e) {
        _emitError(_errorMessage(e));
      }
    }());
  }

  void deleteMessage(int messageId) {
    unawaited(() async {
      try {
        await chatRepository.deleteMessage(messageId);
      } catch (_) {}
    }());
  }

  void _emitError(String message) {
    _events.add(message);
  }

  static String _errorMessage(Object error) {
    final text = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
    return text.isEmpty ? '操作失败' : text;
  }

  @override
  void dispose() {
    if (chatVisibility.foregroundSessionId == sessionId) {
      chatVisibility.foregroundSessionId = null;
    }
    for (final sub in _subs) {
      sub.cancel();
    }
    _events.close();
    super.dispose();
  }
}

/// Best-effort mime guess by extension, mirroring the platform resolver the
/// Android app used.
String guessMime(String name) {
  final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'heic' || 'heif' => 'image/heic',
    'svg' => 'image/svg+xml',
    'mp4' => 'video/mp4',
    'm4a' => 'audio/mp4',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'ogg' => 'audio/ogg',
    'opus' => 'audio/ogg',
    'flac' => 'audio/flac',
    'aac' => 'audio/aac',
    'txt' => 'text/plain',
    'md' || 'markdown' => 'text/markdown',
    'csv' => 'text/csv',
    'html' || 'htm' => 'text/html',
    'xml' => 'text/xml',
    'json' => 'application/json',
    'pdf' => 'application/pdf',
    'zip' => 'application/zip',
    'gz' => 'application/gzip',
    'tar' => 'application/x-tar',
    'py' => 'text/x-python',
    'js' => 'text/javascript',
    'ts' => 'text/typescript',
    'kt' => 'text/x-kotlin',
    'java' => 'text/x-java-source',
    'c' => 'text/x-c',
    'cpp' || 'cc' => 'text/x-c++',
    'h' => 'text/x-header',
    'sh' => 'application/x-sh',
    'yaml' || 'yml' => 'application/yaml',
    _ => 'application/octet-stream',
  };
}
