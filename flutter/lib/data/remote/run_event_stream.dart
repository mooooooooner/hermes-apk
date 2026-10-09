import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../prefs/settings_repository.dart';
import 'dtos.dart';
import 'interceptors.dart';

/// Live event stream for an async run (`GET /v1/runs/{id}/events`).
///
/// Hand-rolled SSE parsing over a dio streamed response:
///  - `: keepalive` comment lines are ignored (must not be mistaken for a drop);
///  - a dropped connection surfaces as a stream error instead of a silent hang;
///  - the event name lives in the JSON `event` field, not on an SSE `event:` line.
class RunEventStream {
  final Dio _dio;

  RunEventStream(SettingsRepository settings)
      : _dio = Dio(BaseOptions(
          baseUrl: 'http://localhost/', // placeholder; rewritten per request
          connectTimeout: const Duration(seconds: 30),
          // SSE connections stay open indefinitely; no read timeout.
          receiveTimeout: null,
          sendTimeout: null,
        )) {
    _dio.interceptors.add(DynamicUrlInterceptor(settings));
  }

  /// Events are delivered without unbounded buffering concerns: Dart stream
  /// events are queued by the single-subscription controller until the
  /// consumer processes them, so a burst of deltas can never be dropped.
  Stream<RunEventDto> events(String runId) async* {
    final response = await _dio.get<ResponseBody>(
      'v1/runs/$runId/events',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'HTTP ${response.statusCode}',
      );
    }
    final body = response.data!;
    final buffer = StringBuffer();
    await for (final chunk in body.stream) {
      buffer.write(utf8.decode(chunk));
      // Frames are separated by a blank line. `\r\n` is tolerated.
      var text = buffer.toString();
      int sep;
      while ((sep = _frameSeparatorIndex(text)) >= 0) {
        final frame = text.substring(0, sep);
        text = text.substring(sep + _separatorLengthAt(text, sep));
        final event = _parseFrame(frame);
        if (event != null) yield event;
      }
      buffer
        ..clear()
        ..write(text);
    }
    // Flush any trailing frame that lacked a final blank line.
    final tail = buffer.toString();
    final event = _parseFrame(tail);
    if (event != null) yield event;
  }

  /// Finds the index of a `\n\n`, `\r\n\r\n` or `\n\r\n`-style blank-line
  /// separator (SSE tolerant parsing).
  static int _frameSeparatorIndex(String text) {
    for (var i = 0; i < text.length - 1; i++) {
      final c = text[i];
      if (c != '\n' && c != '\r') continue;
      final next = text[i + 1];
      if (c == '\r' && next == '\n') {
        if (i + 3 < text.length &&
            text[i + 2] == '\r' &&
            text[i + 3] == '\n') {
          return i;
        }
        continue;
      }
      if (c == '\n') {
        if (next == '\n') return i;
        if (next == '\r' && i + 2 < text.length && text[i + 2] == '\n') return i;
      }
    }
    return -1;
  }

  static int _separatorLengthAt(String text, int index) {
    final c = text[index];
    if (c == '\r') return 4; // \r\n\r\n
    final next = text[index + 1];
    if (next == '\r') return 3; // \n\r\n
    return 2; // \n\n
  }

  static RunEventDto? _parseFrame(String frame) {
    final dataLines = <String>[];
    for (final line in frame.split('\n')) {
      var l = line.trimRight();
      if (l.endsWith('\r')) l = l.substring(0, l.length - 1);
      if (l.isEmpty) continue;
      if (l.startsWith(':')) continue; // comment / keepalive
      if (l.startsWith('data:')) {
        dataLines.add(l.substring(5).trimLeft());
      }
      // `event:` / `id:` / `retry:` lines carry nothing this client needs.
    }
    if (dataLines.isEmpty) return null;
    final data = dataLines.join('\n');
    if (data.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return RunEventDto.fromJson(decoded);
      }
      return null;
    } on FormatException {
      return null;
    }
  }
}
