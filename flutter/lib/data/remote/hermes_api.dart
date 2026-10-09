import 'package:dio/dio.dart';

import '../prefs/settings_repository.dart';
import 'dtos.dart';
import 'interceptors.dart';

/// Hermes OpenAI-compatible API.
///
/// The real base URL is injected per request by [DynamicUrlInterceptor], so the
/// paths here are relative to whatever Base URL the user configured.
class HermesApi {
  final Dio _dio;

  HermesApi(SettingsRepository settings)
      : _dio = Dio(BaseOptions(
          baseUrl: 'http://localhost/', // placeholder; rewritten per request
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 90),
        )) {
    _dio.interceptors.add(DynamicUrlInterceptor(settings));
  }

  Future<HealthResponse> health() async =>
      HealthResponse.fromJson(await _getJson('health'));

  Future<ModelsResponse> listModels() async =>
      ModelsResponse.fromJson(await _getJson('v1/models'));

  Future<Capabilities> capabilities() async =>
      Capabilities.fromJson(await _getJson('v1/capabilities'));

  Future<RunCreatedDto> createRun(RunRequest body, {String? idempotencyKey}) async {
    final data = await _postJson(
      'v1/runs',
      body.toJson(),
      headers: idempotencyKey == null
          ? null
          : {'Idempotency-Key': idempotencyKey},
    );
    return RunCreatedDto.fromJson(data);
  }

  Future<RunStatusDto> runStatus(String runId) async =>
      RunStatusDto.fromJson(await _getJson('v1/runs/$runId'));

  Future<void> stopRun(String runId) async {
    await _dio.post<void>('v1/runs/$runId/stop');
  }

  Future<void> steerRun(String runId, String input) async {
    await _dio.post<void>('v1/runs/$runId/steer', data: {'input': input});
  }

  Future<SessionMessagesResponse> sessionMessages(String sessionId,
      {int limit = 500}) async {
    final data = await _getJson('api/sessions/$sessionId/messages',
        query: {'limit': limit});
    return SessionMessagesResponse.fromJson(data);
  }

  /// List every session known to the server (including ones created outside
  /// this app).
  Future<ServerSessionsResponse> listSessions(
      {int limit = 200, int offset = 0}) async {
    final data = await _getJson('api/sessions', query: {
      'limit': limit,
      'offset': offset,
    });
    return ServerSessionsResponse.fromJson(data);
  }

  /// Delete a session on the server so it disappears for every client.
  /// Returns normally; check [DioException] status 404 at call sites.
  Future<void> deleteSession(String sessionId) async {
    await _dio.delete<void>('api/sessions/$sessionId');
  }

  // ---------------------------------------------------------------- helpers

  Future<Map<String, dynamic>> _getJson(String path,
      {Map<String, dynamic>? query}) async {
    final response = await _dio.get<dynamic>(path,
        queryParameters: query,
        options: Options(responseType: ResponseType.json));
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> _postJson(String path, Object? body,
      {Map<String, String>? headers}) async {
    final response = await _dio.post<dynamic>(path,
        data: body,
        options: Options(
          responseType: ResponseType.json,
          headers: headers,
        ));
    return Map<String, dynamic>.from(response.data as Map);
  }
}
