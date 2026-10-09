import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/prefs/settings_repository.dart';
import '../../data/remote/hermes_api.dart';

sealed class ConnectionTest {
  const ConnectionTest();
}

class ConnectionTestIdle extends ConnectionTest {
  const ConnectionTestIdle();
}

class ConnectionTestLoading extends ConnectionTest {
  const ConnectionTestLoading();
}

class ConnectionTestSuccess extends ConnectionTest {
  final List<String> models;

  /// True when the configured Base URL uses plaintext http://.
  final bool insecureUrl;

  const ConnectionTestSuccess({required this.models, this.insecureUrl = false});
}

class ConnectionTestFailure extends ConnectionTest {
  final String message;
  const ConnectionTestFailure(this.message);
}

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository settingsRepository;
  final HermesApi api;

  SettingsViewModel({required this.settingsRepository, required this.api}) {
    _subs.add(settingsRepository.settings.listen((s) {
      settings = s;
      notifyListeners();
    }));
  }

  final _subs = <StreamSubscription<dynamic>>[];

  AppSettings settings = const AppSettings();
  ConnectionTest test = const ConnectionTestIdle();

  Future<void> saveConnection(String baseUrl, String apiKey) async {
    await settingsRepository.setBaseUrl(baseUrl);
    await settingsRepository.setApiKey(apiKey);
  }

  Future<void> saveSystemInstructions(String value) =>
      settingsRepository.setSystemInstructions(value);

  Future<void> setThemeMode(AppThemeMode mode) =>
      settingsRepository.setThemeMode(mode);

  Future<void> setDynamicColor(bool enabled) =>
      settingsRepository.setDynamicColor(enabled);

  Future<void> setToolProgress(bool enabled) =>
      settingsRepository.setToolProgress(enabled);

  Future<void> setAssistantName(String name) =>
      settingsRepository.setAssistantName(name);

  Future<void> setFilesBaseUrl(String value) =>
      settingsRepository.setFilesBaseUrl(value);

  /// Copy the picked image into app storage so it survives the original file
  /// being moved or deleted.
  Future<void> setAssistantAvatar(String pickedPath) async {
    try {
      final bytes = await File(pickedPath).readAsBytes();
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path,
          'assistant_avatar_${DateTime.now().millisecondsSinceEpoch}.img'));
      await file.writeAsBytes(bytes);
      await settingsRepository.setAssistantAvatarPath(file.path);
    } catch (_) {}
  }

  Future<void> clearAssistantAvatar() =>
      settingsRepository.setAssistantAvatarPath('');

  /// Persist the current form values first, then probe `GET /v1/models`.
  void testConnection(String baseUrl, String apiKey) {
    unawaited(() async {
      await settingsRepository.setBaseUrl(baseUrl);
      await settingsRepository.setApiKey(apiKey);
      test = const ConnectionTestLoading();
      notifyListeners();
      final insecure = baseUrl.trim().toLowerCase().startsWith('http://');
      try {
        final response = await api.listModels();
        test = ConnectionTestSuccess(
          models: response.data
              .map((m) => m.id)
              .whereType<String>()
              .toList(),
          insecureUrl: insecure,
        );
      } catch (error) {
        test = ConnectionTestFailure(
            error.toString().replaceFirst(RegExp(r'^Exception: '), ''));
      }
      notifyListeners();
    }());
  }

  void clearTest() {
    test = const ConnectionTestIdle();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
