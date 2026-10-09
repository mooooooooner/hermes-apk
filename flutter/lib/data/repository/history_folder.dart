import '../local/rows.dart';
import '../models.dart';
import '../remote/dtos.dart';

/// Folds the server transcript (assistant turns + their tool results) into the
/// same ordered [MessageSegment] model the streaming path produces, so a synced
/// conversation renders identically to one that was streamed live.
///
/// Shared by manual sync (ChatRepository.fetchHistory) and the silent
/// post-completion refresh in RunManager, so both paths produce byte-for-byte
/// the same local shape.
class HistoryFolder {
  static List<LocalMessage> fold(
    String sessionId,
    List<ServerMessage> data, {
    List<LocalMessage> previous = const [],
    int? now,
  }) {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final entities = <LocalMessage>[];
    final pending = <ServerMessage>[];

    // Local user messages, consumed in order, so attachments survive a server
    // sync (the server transcript does not carry the app's local attachment URIs).
    final previousUsers =
        previous.where((m) => m.role == MessageRole.user).toList();

    void flushAssistant() {
      if (pending.isEmpty) return;
      final segments = buildSegments(pending);
      pending.clear();
      if (segments.every((s) => s.isEmpty)) return;
      entities.add(LocalMessage(
        sessionId: sessionId,
        role: MessageRole.assistant,
        content: segments
            .map((s) => s.text.trim())
            .where((t) => t.isNotEmpty)
            .join('\n\n'),
        reasoning: segments
            .map((s) => s.reasoning.trim())
            .where((t) => t.isNotEmpty)
            .join('\n\n'),
        status: MessageStatus.complete,
        seq: entities.length + 1,
        createdAt: nowMs,
        updatedAt: nowMs,
        toolEvents: segments.expand((s) => s.tools).toList(),
        segments: segments,
      ));
    }

    for (final server in data) {
      switch (server.role) {
        case 'user':
          flushAssistant();
          final content = contentToText(server.content);
          var preserved = const <Attachment>[];
          final matchIndex =
              previousUsers.indexWhere((m) => m.content == content);
          if (matchIndex >= 0) {
            preserved = previousUsers.removeAt(matchIndex).attachments;
          }
          entities.add(LocalMessage(
            sessionId: sessionId,
            role: MessageRole.user,
            content: content,
            status: MessageStatus.complete,
            seq: entities.length + 1,
            createdAt: _secondsToMillis(server.timestamp) ?? nowMs,
            updatedAt: nowMs,
            attachments:
                preserved.isNotEmpty ? preserved : contentToAttachments(server.content),
            serverId: server.id,
          ));
        case 'assistant':
        case 'tool':
          pending.add(server);
        default:
          break;
      }
    }
    flushAssistant();
    final merged = mergeLocalOnlyTurns(serverEntities: entities, previous: previous);
    return reuseLocalIds(merged, previous);
  }

  static int? _secondsToMillis(double? seconds) {
    final millis = ((seconds ?? 0) * 1000).round();
    return millis > 0 ? millis : null;
  }

  /// Reuse the local row id (and creation time) of messages that already exist,
  /// so a sync does not churn primary keys: stable ids keep the list items
  /// mounted instead of re-creating the whole list (no flash, no scroll jump).
  static List<LocalMessage> reuseLocalIds(
    List<LocalMessage> entities,
    List<LocalMessage> previous,
  ) {
    if (previous.isEmpty) return entities;
    final result = entities.toList();
    final unused = previous.toList();
    // Index-aligned pass handles the common case (same conversation, same order).
    for (var index = 0; index < result.length; index++) {
      final entity = result[index];
      if (index >= previous.length) break;
      final old = previous[index];
      if (old.role == entity.role && old.content == entity.content) {
        result[index] = entity.copyWith(id: old.id, createdAt: old.createdAt);
        unused.remove(old);
      }
    }
    // Fallback pass for messages shifted by insertions/deletions: match by
    // role + content.
    for (var index = 0; index < result.length; index++) {
      final entity = result[index];
      if (entity.id != 0) continue;
      final oldIndex = unused.indexWhere(
          (m) => m.role == entity.role && m.content == entity.content);
      if (oldIndex < 0) continue;
      final old = unused.removeAt(oldIndex);
      result[index] = entity.copyWith(id: old.id, createdAt: old.createdAt);
    }
    return result;
  }

  /// Keep the turns the server transcript does not contain. A slash command is
  /// answered server-side **without an agent turn**, so it is never written to
  /// the session transcript. Re-insert those local-only turns in their original
  /// position so a sync (automatic or manual) leaves the conversation unchanged.
  static List<LocalMessage> mergeLocalOnlyTurns({
    required List<LocalMessage> serverEntities,
    required List<LocalMessage> previous,
  }) {
    final localTurns = groupTurns(previous);
    // Fast path: with nothing but persisted turns the transcript stays authoritative.
    if (!localTurns.any((turn) =>
        turn.isNotEmpty && _startsWithSlashCommand(turn.first))) {
      return serverEntities;
    }
    final serverTurns = groupTurns(serverEntities);
    final merged = <LocalMessage>[];
    var s = 0;
    for (final turn in localTurns) {
      final serverTurn = s < serverTurns.length ? serverTurns[s] : null;
      if (_isLocalOnlyTurn(turn, serverTurn)) {
        merged.addAll(turn);
      } else if (serverTurn != null) {
        merged.addAll(serverTurn);
        s++;
      } else {
        merged.addAll(turn);
      }
    }
    while (s < serverTurns.length) {
      merged.addAll(serverTurns[s]);
      s++;
    }
    return [
      for (var index = 0; index < merged.length; index++)
        merged[index].seq == index + 1
            ? merged[index]
            : merged[index].copyWith(seq: index + 1),
    ];
  }

  /// A turn is a user message plus everything after it up to (not including)
  /// the next user message.
  static List<List<LocalMessage>> groupTurns(List<LocalMessage> messages) {
    final turns = <List<LocalMessage>>[];
    for (final message in messages) {
      if (message.role == MessageRole.user || turns.isEmpty) {
        turns.add([message]);
      } else {
        turns.last.add(message);
      }
    }
    return turns;
  }

  static bool _startsWithSlashCommand(LocalMessage message) =>
      message.role == MessageRole.user &&
      message.content.trimLeft().startsWith('/');

  static bool _isLocalOnlyTurn(
    List<LocalMessage> localTurn,
    List<LocalMessage>? serverTurn,
  ) {
    if (localTurn.isEmpty) return false;
    final localUser = localTurn.first;
    if (!_startsWithSlashCommand(localUser)) return false;
    final serverUser = serverTurn?.firstOrNull;
    // The server *did* persist this turn (e.g. an unknown "/foo" still goes
    // through the model) when its user text matches; only a real server-side
    // command leaves no transcript row.
    return serverUser == null ||
        serverUser.role != MessageRole.user ||
        serverUser.content.trim() != localUser.content.trim();
  }

  static List<MessageSegment> buildSegments(List<ServerMessage> messages) {
    final segments = <MessageSegment>[];
    for (final message in messages) {
      switch (message.role) {
        case 'assistant':
          segments.add(MessageSegment(
            reasoning: message.reasoning ?? message.reasoningContent ?? '',
            tools: parseToolCalls(message.toolCalls),
            text: contentToText(message.content),
          ));
        case 'tool':
          final result = contentToText(message.content);
          final id = message.toolCallId;
          var matched = false;
          if (id != null) {
            for (var i = segments.length - 1; i >= 0; i--) {
              final tools = segments[i].tools;
              final index = tools.indexWhere((t) => t.id == id);
              if (index >= 0) {
                final copy = List<ToolEvent>.of(tools);
                copy[index] =
                    copy[index].copyWith(status: 'completed', result: result);
                segments[i] = _withTools(segments[i], copy);
                matched = true;
                break;
              }
            }
          }
          if (!matched) {
            for (var i = 0; i < segments.length; i++) {
              final tools = segments[i].tools;
              final index = tools.indexWhere((t) => t.result == null);
              if (index >= 0) {
                final copy = List<ToolEvent>.of(tools);
                copy[index] = copy[index].copyWith(
                  status: 'completed',
                  result: result,
                  name:
                      copy[index].name.isNotEmpty ? copy[index].name : (message.toolName ?? 'tool'),
                );
                segments[i] = _withTools(segments[i], copy);
                matched = true;
                break;
              }
            }
          }
          if (!matched) {
            segments.add(MessageSegment(tools: [
              ToolEvent(
                id: id ?? 'tool-${segments.length}',
                name: message.toolName ?? 'tool',
                status: 'completed',
                result: result,
              ),
            ]));
          }
        default:
          break;
      }
    }
    return segments;
  }

  static MessageSegment _withTools(MessageSegment s, List<ToolEvent> tools) =>
      MessageSegment(reasoning: s.reasoning, tools: tools, text: s.text);

  static List<ToolEvent> parseToolCalls(Object? element) {
    if (element is! List) return const [];
    final out = <ToolEvent>[];
    for (final part in element) {
      if (part is! Map) continue;
      final obj = Map<String, dynamic>.from(part);
      final id = obj['id'] as String? ?? obj['call_id'] as String? ?? 'call-${out.length}';
      final function = obj['function'];
      String name = 'tool';
      String? arguments;
      if (function is Map) {
        final fnName = function['name'];
        if (fnName is String && fnName.isNotEmpty) name = fnName;
        final args = function['arguments'];
        if (args is String) {
          arguments = args;
        } else if (args != null) {
          arguments = args.toString();
        }
      } else {
        final objName = obj['name'];
        if (objName is String && objName.isNotEmpty) name = objName;
      }
      out.add(ToolEvent(id: id, name: name, status: 'started', preview: arguments));
    }
    return out;
  }
}

/// Extract plain text from a server message `content` which may be a string or
/// an array of parts.
String contentToText(Object? content) {
  if (content == null) return '';
  if (content is String) return content;
  if (content is List) {
    return content
        .map((part) {
          if (part is! Map) return '';
          final type = part['type'];
          switch (type) {
            case 'input_text':
            case 'text':
            case 'output_text':
              final text = part['text'];
              return text is String ? text : '';
            case 'image_url':
            case 'input_image':
              return '[图片]';
            default:
              final text = part['text'];
              return text is String ? text : '';
          }
        })
        .join('\n')
        .trim();
  }
  return content.toString();
}

/// Extract image / file attachments from a server message content array, if any.
List<Attachment> contentToAttachments(Object? content) {
  if (content is! List) return const [];
  final out = <Attachment>[];
  for (var index = 0; index < content.length; index++) {
    final part = content[index];
    if (part is! Map) continue;
    final type = part['type'];
    if (type != 'image_url' && type != 'input_image') continue;
    final imageToken = part['image_url'];
    String? url;
    if (imageToken is Map) {
      final u = imageToken['url'];
      if (u is String) url = u;
    } else if (imageToken is String) {
      url = imageToken;
    }
    if (url == null) continue;
    out.add(Attachment(
      id: 'server-img-$index',
      name: 'image-$index',
      mimeType: 'image/*',
      size: 0,
      uri: url,
      kind: AttachmentKind.image,
    ));
  }
  return out;
}
