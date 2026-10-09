/// Domain models, enums and their JSON codecs.
///
/// JSON field names intentionally mirror the Kotlin/Gson originals (including
/// enum names serialized as UPPER_CASE, e.g. `"IMAGE"`, `"PENDING"`) so local
/// data keeps the exact shape the Android app produced.
library;

enum MessageRole { user, assistant, system, tool }

MessageRole messageRoleFrom(String? raw) {
  switch (raw) {
    case 'USER':
      return MessageRole.user;
    case 'SYSTEM':
      return MessageRole.system;
    case 'TOOL':
      return MessageRole.tool;
    default:
      return MessageRole.assistant;
  }
}

enum MessageStatus { pending, streaming, complete, error, cancelled }

MessageStatus messageStatusFrom(String? raw) {
  switch (raw) {
    case 'PENDING':
      return MessageStatus.pending;
    case 'STREAMING':
      return MessageStatus.streaming;
    case 'ERROR':
      return MessageStatus.error;
    case 'CANCELLED':
      return MessageStatus.cancelled;
    default:
      return MessageStatus.complete;
  }
}

enum AttachmentKind { image, file }

AttachmentKind attachmentKindFrom(String? raw) =>
    raw == 'FILE' ? AttachmentKind.file : AttachmentKind.image;

extension AttachmentKindName on AttachmentKind {
  String get wireName => this == AttachmentKind.file ? 'FILE' : 'IMAGE';
}

class Attachment {
  final String id;
  final String name;
  final String mimeType;
  final int size;
  final String uri;
  final AttachmentKind kind;

  const Attachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.uri,
    required this.kind,
  });

  Attachment copyWith({String? name, int? size}) => Attachment(
        id: id,
        name: name ?? this.name,
        mimeType: mimeType,
        size: size ?? this.size,
        uri: uri,
        kind: kind,
      );

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        uri: json['uri'] as String? ?? '',
        kind: attachmentKindFrom(json['kind'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mimeType': mimeType,
        'size': size,
        'uri': uri,
        'kind': kind.wireName,
      };
}

class ToolEvent {
  final String id;
  final String name;
  final String status; // started | completed | subagent_start | subagent_complete
  final String? preview; // tool arguments (pretty printed)
  final String? result; // tool result preview (truncated by server)
  final int? durationMs;
  final bool error;
  final int startedAt;

  const ToolEvent({
    required this.id,
    required this.name,
    required this.status,
    this.preview,
    this.result,
    this.durationMs,
    this.error = false,
    this.startedAt = 0,
  });

  ToolEvent copyWith({
    String? status,
    String? result,
    int? durationMs,
    bool? error,
    String? name,
  }) =>
      ToolEvent(
        id: id,
        name: name ?? this.name,
        status: status ?? this.status,
        preview: preview,
        result: result ?? this.result,
        durationMs: durationMs ?? this.durationMs,
        error: error ?? this.error,
        startedAt: startedAt,
      );

  factory ToolEvent.fromJson(Map<String, dynamic> json) => ToolEvent(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? '',
        preview: json['preview'] as String?,
        result: json['result'] as String?,
        durationMs: (json['durationMs'] as num?)?.toInt(),
        error: json['error'] as bool? ?? false,
        startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        if (preview != null) 'preview': preview,
        if (result != null) 'result': result,
        if (durationMs != null) 'durationMs': durationMs,
        'error': error,
        'startedAt': startedAt,
      };
}

class Usage {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;

  const Usage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
  });

  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
        inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
        totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
        cacheReadTokens: (json['cacheReadTokens'] as num?)?.toInt() ?? 0,
        cacheWriteTokens: (json['cacheWriteTokens'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'totalTokens': totalTokens,
        'cacheReadTokens': cacheReadTokens,
        'cacheWriteTokens': cacheWriteTokens,
      };
}

/// One "round" of an agent turn, rendered in order as 思维链 → toolcall → 正文.
class MessageSegment {
  final String reasoning;
  final List<ToolEvent> tools;
  final String text;

  const MessageSegment({
    this.reasoning = '',
    this.tools = const [],
    this.text = '',
  });

  bool get isEmpty => reasoning.trim().isEmpty && tools.isEmpty && text.trim().isEmpty;

  factory MessageSegment.fromJson(Map<String, dynamic> json) => MessageSegment(
        reasoning: json['reasoning'] as String? ?? '',
        text: json['text'] as String? ?? '',
        tools: (json['tools'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => ToolEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'reasoning': reasoning,
        'tools': tools.map((e) => e.toJson()).toList(),
        'text': text,
      };
}

enum RunState {
  queued,
  started,
  running,
  completed,
  failed,
  cancelled,
  interrupted,
  unknown;

  bool get isTerminal =>
      this == completed || this == failed || this == cancelled || this == interrupted;

  bool get isActive => !isTerminal;

  static RunState from(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'queued':
        return queued;
      case 'started':
        return started;
      case 'running':
      case 'in_progress':
        return running;
      case 'completed':
      case 'complete':
      case 'succeeded':
        return completed;
      case 'failed':
      case 'error':
        return failed;
      case 'cancelled':
      case 'canceled':
        return cancelled;
      case 'interrupted':
        return interrupted;
      default:
        return unknown;
    }
  }
}

/// UI-facing aggregate of a chat message.
class ChatMessage {
  final int id;
  final String sessionId;
  final MessageRole role;
  final String content;
  final String reasoning;
  final MessageStatus status;
  final String? runId;
  final int seq;
  final int createdAt;
  final int updatedAt;
  final List<Attachment> attachments;
  final List<ToolEvent> toolEvents;
  final List<MessageSegment> segments;
  final String? error;
  final Usage? usage;
  final RunState? runState;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.reasoning,
    required this.status,
    this.runId,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
    this.toolEvents = const [],
    this.segments = const [],
    this.error,
    this.usage,
    this.runState,
  });

  /// Segments to render; synthesised from legacy aggregate fields when absent.
  List<MessageSegment> get renderSegments {
    if (segments.isNotEmpty) return segments;
    return [
      MessageSegment(reasoning: reasoning, tools: toolEvents, text: content),
    ].where((s) => !s.isEmpty).toList();
  }

  /// The final answer (last non-blank segment text), used for previews and notifications.
  String get finalText {
    for (final s in renderSegments.reversed) {
      if (s.text.trim().isNotEmpty) return s.text;
    }
    return content;
  }
}

class ChatSession {
  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final String preview;
  final String? activeRunId;
  final RunState? activeRunState;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.preview = '',
    this.activeRunId,
    this.activeRunState,
  });
}
