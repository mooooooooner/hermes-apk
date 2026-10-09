import 'package:dio/dio.dart';

import '../prefs/settings_repository.dart';
import 'url_resolver.dart';

/// Rewrites every outgoing request onto the user-configured Base URL (which may
/// include a path prefix) and attaches the Bearer token. Callers must build
/// requests with only the **relative** path (placeholder host
/// `http://localhost/...`); the configured base path is then prepended exactly
/// once.
class DynamicUrlInterceptor extends Interceptor {
  final SettingsRepository settings;

  DynamicUrlInterceptor(this.settings);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final base = settings.cachedBaseUrl.trim();
      if (base.isEmpty) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: '尚未配置服务器地址，请先在设置中填写 Base URL',
        );
      }
      final newUrl = resolveUri(base, options.uri);
      options.baseUrl = '';
      options.path = newUrl.toString();
      options.queryParameters.clear();
      final key = settings.cachedApiKey.trim();
      if (key.isNotEmpty && !options.headers.containsKey('Authorization')) {
        options.headers['Authorization'] = 'Bearer $key';
      }
      handler.next(options);
    } on InvalidBaseUrl catch (e) {
      handler.reject(
        DioException(requestOptions: options, error: e, message: e.toString()),
        true,
      );
    } on DioException catch (e) {
      handler.reject(e, true);
    }
  }
}

/// Resolves every outgoing request onto the user-configured **file-service**
/// base URL and attaches the Bearer token. Mirrors [DynamicUrlInterceptor].
class FilesUrlInterceptor extends Interceptor {
  final SettingsRepository settings;

  FilesUrlInterceptor(this.settings);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final base = settings.cachedFilesBaseUrl.trim();
      if (base.isEmpty) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: '尚未配置文件服务地址',
        );
      }
      final newUrl = resolveUri(base, options.uri);
      options.baseUrl = '';
      options.path = newUrl.toString();
      options.queryParameters.clear();
      final key = settings.cachedApiKey.trim();
      if (key.isNotEmpty && !options.headers.containsKey('Authorization')) {
        options.headers['Authorization'] = 'Bearer $key';
      }
      handler.next(options);
    } on InvalidBaseUrl catch (e) {
      handler.reject(
        DioException(requestOptions: options, error: e, message: e.toString()),
        true,
      );
    } on DioException catch (e) {
      handler.reject(e, true);
    }
  }
}
