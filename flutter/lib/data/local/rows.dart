import 'dart:convert';

import '../models.dart';

/// Plain (codegen-free) row models shared by the DAO boundary, repositories and
/// [HistoryFolder]. The Kotlin app used Room entities the same way; keeping
/// these separate keeps pure logic unit-testable without a database.

class LocalSession {
  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final String preview;
  final String? activeRunId;
  final String? activeRunState;

  const LocalSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.preview = '',
    this.activeRunId,
    this.activeRunState,
  });

  LocalSession copyWith({
    String? title,
    int? updatedAt,
    String? preview,
    String? activeRunId,
    String? activeRunState,
  }) =>
      LocalSession(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        preview: preview ?? this.preview,
        activeRunId: activeRunId ?? this.activeRunId,
        activeRunState: activeRunState ?? this.activeRunState,
      );
}

class LocalMessage {
  final int id; // 0 means "not inserted yet" (autoincrement)
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
  final int? serverId;

  const LocalMessage({
    this.id = 0,
    required this.sessionId,
    required this.role,
    this.content = '',
    this.reasoning = '',
    this.status = MessageStatus.complete,
    this.runId,
    this.seq = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.attachments = const [],
    this.toolEvents = const [],
    this.segments = const [],
    this.error,
    this.usage,
    this.serverId,
  });

  LocalMessage copyWith({
    int? id,
    int? seq,
    String? content,
    String? reasoning,
    MessageStatus? status,
    String? runId,
    List<Attachment>? attachments,
    List<ToolEvent>? toolEvents,
    List<MessageSegment>? segments,
    String? error,
    Usage? usage,
    int? createdAt,
    int? updatedAt,
  }) =>
      LocalMessage(
        id: id ?? this.id,
        sessionId: sessionId,
        role: role,
        content: content ?? this.content,
        reasoning: reasoning ?? this.reasoning,
        status: status ?? this.status,
        runId: runId ?? this.runId,
        seq: seq ?? this.seq,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        attachments: attachments ?? this.attachments,
        toolEvents: toolEvents ?? this.toolEvents,
        segments: segments ?? this.segments,
        error: error ?? this.error,
        usage: usage ?? this.usage,
        serverId: serverId,
      );
}

class LocalRun {
  final String runId;
  final String sessionId;
  final int? userMessageId;
  final int? assistantMessageId;
  final RunState status;
  final String? output;
  final String? error;
  final String? lastEvent;
  final int createdAt;
  final int updatedAt;
  final bool notified;
  final Usage? usage;

  const LocalRun({
    required this.runId,
    required this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
    this.status = RunState.started,
    this.output,
    this.error,
    this.lastEvent,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.notified = false,
    this.usage,
  });

  LocalRun copyWith({
    int? userMessageId,
    int? assistantMessageId,
    RunState? status,
    String? output,
    String? error,
    String? lastEvent,
    int? updatedAt,
    Usage? usage,
  }) =>
      LocalRun(
        runId: runId,
        sessionId: sessionId,
        userMessageId: userMessageId ?? this.userMessageId,
        assistantMessageId: assistantMessageId ?? this.assistantMessageId,
        status: status ?? this.status,
        output: output ?? this.output,
        error: error ?? this.error,
        lastEvent: lastEvent ?? this.lastEvent,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        notified: notified,
        usage: usage ?? this.usage,
      );
}

// ---------------------------------------------------------------------------
// JSON column codecs (same wire shape the Android Room/Gson converters used)
// ---------------------------------------------------------------------------

class AttachmentListJson {
  static String encode(List<Attachment> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());

  static List<Attachment> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on FormatException {
      return const [];
    }
  }
}

class ToolEventListJson {
  static String encode(List<ToolEvent> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());

  static List<ToolEvent> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => ToolEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on FormatException {
      return const [];
    }
  }
}

class SegmentListJson {
  static String encode(List<MessageSegment> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());

  static List<MessageSegment> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => MessageSegment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on FormatException {
      return const [];
    }
  }
}

class UsageJson {
  static String? encode(Usage? value) =>
      value == null ? null : jsonEncode(value.toJson());

  static Usage? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Usage.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    }
  }
}
