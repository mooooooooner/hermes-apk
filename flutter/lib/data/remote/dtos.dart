/// Wire DTOs for the Hermes API and the companion file service.
///
/// All parsers are lenient like Gson: unknown fields ignored, missing fields
/// fall back to defaults/nulls — a malformed server response must never crash
/// the client.
library;

// ---------------------------------------------------------------------------
// GET /v1/models
// ---------------------------------------------------------------------------

class ModelInfo {
  final String? id;
  const ModelInfo({this.id});

  factory ModelInfo.fromJson(Map<String, dynamic> json) =>
      ModelInfo(id: json['id'] as String?);
}

class ModelsResponse {
  final List<ModelInfo> data;
  const ModelsResponse({this.data = const []});

  factory ModelsResponse.fromJson(Map<String, dynamic> json) => ModelsResponse(
        data: (json['data'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => ModelInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// GET /health
// ---------------------------------------------------------------------------

class HealthResponse {
  final String? status;
  final String? platform;
  final String? version;
  const HealthResponse({this.status, this.platform, this.version});

  factory HealthResponse.fromJson(Map<String, dynamic> json) => HealthResponse(
        status: json['status'] as String?,
        platform: json['platform'] as String?,
        version: json['version'] as String?,
      );
}

// ---------------------------------------------------------------------------
// GET /v1/capabilities
// ---------------------------------------------------------------------------

class IdempotencySupport {
  final bool? supported;
  final bool? durable;
  const IdempotencySupport({this.supported, this.durable});

  factory IdempotencySupport.fromJson(Map<String, dynamic> json) =>
      IdempotencySupport(
        supported: json['supported'] as bool?,
        durable: json['durable'] as bool?,
      );
}

class CapabilityFeatures {
  final bool? chatCompletions;
  final bool? runSubmission;
  final bool? runEventsSse;
  final bool? runStop;
  final bool? toolProgressEvents;
  const CapabilityFeatures({
    this.chatCompletions,
    this.runSubmission,
    this.runEventsSse,
    this.runStop,
    this.toolProgressEvents,
  });

  factory CapabilityFeatures.fromJson(Map<String, dynamic> json) =>
      CapabilityFeatures(
        chatCompletions: json['chat_completions'] as bool?,
        runSubmission: json['run_submission'] as bool?,
        runEventsSse: json['run_events_sse'] as bool?,
        runStop: json['run_stop'] as bool?,
        toolProgressEvents: json['tool_progress_events'] as bool?,
      );
}

class Capabilities {
  final String? platform;
  final CapabilityFeatures? features;
  const Capabilities({this.platform, this.features});

  factory Capabilities.fromJson(Map<String, dynamic> json) => Capabilities(
        platform: json['platform'] as String?,
        features: json['features'] is Map
            ? CapabilityFeatures.fromJson(
                Map<String, dynamic>.from(json['features'] as Map))
            : null,
      );
}

// ---------------------------------------------------------------------------
// POST /v1/runs
// ---------------------------------------------------------------------------

/// [input] is either a plain String or an OpenAI-style message list
/// (List<Map>) when multimodal parts are present.
class RunRequest {
  final Object input; // String | List<Map<String, dynamic>>
  final String? sessionId;
  final String? instructions;

  const RunRequest({required this.input, this.sessionId, this.instructions});

  Map<String, dynamic> toJson() => {
        'input': input,
        if (sessionId != null) 'session_id': sessionId,
        if (instructions != null) 'instructions': instructions,
      };
}

class RunCreatedDto {
  /// Nullable: a malformed/edge-case server response must not crash the client.
  final String? runId;
  final String? status;
  final bool replayed;
  const RunCreatedDto({this.runId, this.status, this.replayed = false});

  factory RunCreatedDto.fromJson(Map<String, dynamic> json) => RunCreatedDto(
        runId: json['run_id'] as String?,
        status: json['status'] as String?,
        replayed: json['replayed'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// GET /v1/runs/{id}
// ---------------------------------------------------------------------------

class UsageDto {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  const UsageDto({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
  });

  factory UsageDto.fromJson(Map<String, dynamic>? json) => UsageDto(
        inputTokens: (json?['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json?['output_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: (json?['total_tokens'] as num?)?.toInt() ?? 0,
        cacheReadTokens: (json?['cache_read_tokens'] as num?)?.toInt() ?? 0,
        cacheWriteTokens: (json?['cache_write_tokens'] as num?)?.toInt() ?? 0,
      );
}

class RunStatusDto {
  final String? runId;
  final String? status;
  final String? sessionId;
  final String? output;
  final UsageDto? usage;
  final String? lastEvent;
  final bool completed;
  final bool partial;
  final bool interrupted;
  final Object? error; // decoded JSON (any shape)

  const RunStatusDto({
    this.runId,
    this.status,
    this.sessionId,
    this.output,
    this.usage,
    this.lastEvent,
    this.completed = false,
    this.partial = false,
    this.interrupted = false,
    this.error,
  });

  factory RunStatusDto.fromJson(Map<String, dynamic> json) => RunStatusDto(
        runId: json['run_id'] as String?,
        status: json['status'] as String?,
        sessionId: json['session_id'] as String?,
        output: json['output'] as String?,
        usage: json['usage'] is Map
            ? UsageDto.fromJson(Map<String, dynamic>.from(json['usage'] as Map))
            : null,
        lastEvent: json['last_event'] as String?,
        completed: json['completed'] as bool? ?? false,
        partial: json['partial'] as bool? ?? false,
        interrupted: json['interrupted'] as bool? ?? false,
        error: json['error'],
      );
}

// ---------------------------------------------------------------------------
// SSE payloads from GET /v1/runs/{id}/events
// ---------------------------------------------------------------------------

class RunEventDto {
  final String? event; // the event name lives INSIDE the JSON payload
  final String? runId;
  final int? seq;
  final double? timestamp;
  final String? delta;
  final String? text;
  final String? output;
  final bool alreadyStreamed;
  final String? tool;
  final String? toolName;
  final double? duration; // seconds
  final Object? error; // decoded JSON (any shape)
  final Object? preview; // decoded JSON (any shape)
  final UsageDto? usage;
  final String? subagentId;
  final String? title;

  const RunEventDto({
    this.event,
    this.runId,
    this.seq,
    this.timestamp,
    this.delta,
    this.text,
    this.output,
    this.alreadyStreamed = false,
    this.tool,
    this.toolName,
    this.duration,
    this.error,
    this.preview,
    this.usage,
    this.subagentId,
    this.title,
  });

  factory RunEventDto.fromJson(Map<String, dynamic> json) => RunEventDto(
        event: json['event'] as String?,
        runId: json['run_id'] as String?,
        seq: (json['seq'] as num?)?.toInt(),
        timestamp: (json['timestamp'] as num?)?.toDouble(),
        delta: json['delta'] as String?,
        text: json['text'] as String?,
        output: json['output'] as String?,
        alreadyStreamed: json['already_streamed'] as bool? ?? false,
        tool: json['tool'] as String?,
        toolName: json['tool_name'] as String?,
        duration: (json['duration'] as num?)?.toDouble(),
        error: json['error'],
        preview: json['preview'],
        usage: json['usage'] is Map
            ? UsageDto.fromJson(Map<String, dynamic>.from(json['usage'] as Map))
            : null,
        subagentId: json['subagent_id'] as String?,
        title: json['title'] as String?,
      );
}

// ---------------------------------------------------------------------------
// GET /api/sessions, GET /api/sessions/{id}/messages
// ---------------------------------------------------------------------------

class ServerSession {
  final String id;
  final String? title;
  final double? startedAt;
  final double? lastActive;
  final String? preview;
  final String? parentSessionId;
  final bool hidden;
  final bool isInternalChild;

  const ServerSession({
    this.id = '',
    this.title,
    this.startedAt,
    this.lastActive,
    this.preview,
    this.parentSessionId,
    this.hidden = false,
    this.isInternalChild = false,
  });

  factory ServerSession.fromJson(Map<String, dynamic> json) => ServerSession(
        id: json['id'] as String? ?? '',
        title: json['title'] as String?,
        startedAt: (json['started_at'] as num?)?.toDouble(),
        lastActive: (json['last_active'] as num?)?.toDouble(),
        preview: json['preview'] as String?,
        parentSessionId: json['parent_session_id'] as String?,
        hidden: json['hidden'] as bool? ?? false,
        isInternalChild: json['is_internal_child'] as bool? ?? false,
      );
}

class ServerSessionsResponse {
  final List<ServerSession> data;
  final bool hasMore;
  const ServerSessionsResponse({this.data = const [], this.hasMore = false});

  factory ServerSessionsResponse.fromJson(Map<String, dynamic> json) =>
      ServerSessionsResponse(
        data: (json['data'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => ServerSession.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        hasMore: json['has_more'] as bool? ?? false,
      );
}

class ServerMessage {
  final int? id;
  final String? role;
  final Object? content; // decoded JSON: String or List of parts
  final String? toolCallId;
  final Object? toolCalls; // decoded JSON array
  final String? toolName;
  final double? timestamp;
  final String? reasoning;
  final String? reasoningContent;

  const ServerMessage({
    this.id,
    this.role,
    this.content,
    this.toolCallId,
    this.toolCalls,
    this.toolName,
    this.timestamp,
    this.reasoning,
    this.reasoningContent,
  });

  factory ServerMessage.fromJson(Map<String, dynamic> json) => ServerMessage(
        id: (json['id'] as num?)?.toInt(),
        role: json['role'] as String?,
        content: json['content'],
        toolCallId: json['tool_call_id'] as String?,
        toolCalls: json['tool_calls'],
        toolName: json['tool_name'] as String?,
        timestamp: (json['timestamp'] as num?)?.toDouble(),
        reasoning: json['reasoning'] as String?,
        reasoningContent: json['reasoning_content'] as String?,
      );
}

class SessionMessagesResponse {
  final List<ServerMessage> data;
  const SessionMessagesResponse({this.data = const []});

  factory SessionMessagesResponse.fromJson(Map<String, dynamic> json) =>
      SessionMessagesResponse(
        data: (json['data'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => ServerMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// File service
// ---------------------------------------------------------------------------

/// Response of `POST /upload` on the companion file service.
class UploadedFileDto {
  final String? id;
  final String? name;
  final int size;
  final String? mime;

  /// Absolute path on the server, usable directly by the agent's file tools.
  final String? path;

  /// Public URL the app can fetch the bytes from.
  final String? url;
  const UploadedFileDto({
    this.id,
    this.name,
    this.size = 0,
    this.mime,
    this.path,
    this.url,
  });

  factory UploadedFileDto.fromJson(Map<String, dynamic> json) =>
      UploadedFileDto(
        id: json['id'] as String?,
        name: json['name'] as String?,
        size: (json['size'] as num?)?.toInt() ?? 0,
        mime: json['mime'] as String?,
        path: json['path'] as String?,
        url: json['url'] as String?,
      );
}

/// One entry of `GET /commands` (server-editable slash-command list).
class CommandDto {
  final String name;
  final String? description;
  final String? template;
  const CommandDto({this.name = '', this.description, this.template});

  factory CommandDto.fromJson(Map<String, dynamic> json) => CommandDto(
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        template: json['template'] as String?,
      );
}
