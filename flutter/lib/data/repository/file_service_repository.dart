import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import '../prefs/settings_repository.dart';
import '../remote/files_api.dart';
import '../remote/dtos.dart';

/// Client for the companion file service. Two directions:
///
///  - **user -> agent**: attachments are uploaded here; the server-local
///    `path` is injected into the run so the agent can read the file directly.
///  - **agent -> user**: the agent uploads via the same service; the app loads
///    the returned URL (images inline, other files downloaded on tap).
class FileServiceRepository {
  final FilesApi api;
  final SettingsRepository settings;

  FileServiceRepository(this.api, this.settings);

  /// Upload one attachment. Returns null on any failure so the caller can
  /// fall back to inlining.
  Future<UploadedFileDto?> upload(Attachment attachment) async {
    try {
      return await api.upload(
        attachment.uri,
        attachment.name.isNotEmpty ? attachment.name : 'upload.bin',
        attachment.mimeType.isNotEmpty
            ? attachment.mimeType
            : 'application/octet-stream',
        attachment.size > 0 ? attachment.size : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<CommandDto>> commands() async {
    try {
      return (await api.commands()).where((c) => c.name.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  bool isFilesUrl(String url) {
    var base = settings.cachedFilesBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base.isNotEmpty && url.startsWith(base);
  }

  String? fileId(String url) {
    const marker = '/files/';
    final index = url.indexOf(marker);
    if (index < 0) return null;
    var id = url.substring(index + marker.length);
    final q = id.indexOf('?');
    if (q >= 0) id = id.substring(0, q);
    final h = id.indexOf('#');
    if (h >= 0) id = id.substring(0, h);
    return id.isEmpty ? null : id;
  }

  /// Download a file-service URL into the app cache so it can be opened/shared.
  Future<File?> downloadToCache(String url, String? name) async {
    try {
      final id = fileId(url);
      if (id == null) return null;
      final safeSource = name ?? id;
      final safeName =
          safeSource.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final root = await getTemporaryDirectory();
      final dir = Directory(p.join(root.path, 'downloads'));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      } else {
        // Keep the cache bounded: drop anything older than a week.
        final cutoff =
            DateTime.now().millisecondsSinceEpoch - _cacheTtlMs;
        for (final entity in dir.listSync()) {
          if (entity is File) {
            final modified = entity.lastModifiedSync().millisecondsSinceEpoch;
            if (modified < cutoff) entity.deleteSync();
          }
        }
      }
      final target = File(p.join(dir.path, safeName));
      await api.download(id, target.path);
      return target;
    } catch (_) {
      return null;
    }
  }

  static const _cacheTtlMs = 7 * 24 * 60 * 60 * 1000;
}
