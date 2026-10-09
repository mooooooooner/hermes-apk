import 'package:dio/dio.dart';

import '../prefs/settings_repository.dart';
import 'dtos.dart';
import 'interceptors.dart';

/// Companion file service client (bridges files/images between the app and the
/// Hermes server). The real base URL is injected per request by
/// [FilesUrlInterceptor].
class FilesApi {
  final Dio _dio;

  FilesApi(SettingsRepository settings)
      : _dio = Dio(BaseOptions(
          baseUrl: 'http://localhost/', // placeholder; rewritten per request
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 120),
        )) {
    _dio.interceptors.add(FilesUrlInterceptor(settings));
  }

  Future<List<CommandDto>> commands() async {
    final response = await _dio.get<List<dynamic>>('commands');
    return (response.data ?? [])
        .whereType<Map>()
        .map((e) => CommandDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<UploadedFileDto> upload(String filePath, String fileName,
      String mimeType, int? size) async {
    final form = FormData();
    form.files.add(MapEntry(
      'file',
      MultipartFile.fromFileSync(filePath,
          filename: fileName, contentType: DioMediaType.parse(mimeType)),
    ));
    final response = await _dio.post<Map<String, dynamic>>('upload', data: form);
    return UploadedFileDto.fromJson(response.data!);
  }

  /// Download a file by id, streaming into [savePath].
  Future<void> download(String id, String savePath) async {
    await _dio.download('files/$id', savePath);
  }
}
