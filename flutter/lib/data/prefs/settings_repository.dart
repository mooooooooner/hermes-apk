import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Stored as the UPPER_CASE names the Android app used ("SYSTEM"/"LIGHT"/"DARK").
enum AppThemeMode { system, light, dark }

extension AppThemeModeWire on AppThemeMode {
  String get wireName => switch (this) {
        AppThemeMode.system => 'SYSTEM',
        AppThemeMode.light => 'LIGHT',
        AppThemeMode.dark => 'DARK',
      };

  static AppThemeMode fromWire(String? raw) => switch (raw) {
        'LIGHT' => AppThemeMode.light,
        'DARK' => AppThemeMode.dark,
        _ => AppThemeMode.system,
      };
}

class AppSettings {
  static const defaultBaseUrl = 'https://test.monsoons.dev/hermes-api';

  final String baseUrl;
  final String apiKey;
  final AppThemeMode themeMode;
  final bool dynamicColor;
  final String systemInstructions;
  final bool toolProgress;

  /// Display name of the assistant inside a conversation (local only).
  final String assistantName;

  /// Absolute path of the locally stored assistant avatar, or blank for the default icon.
  final String assistantAvatarPath;

  /// Base URL of the companion file service. Blank means "derive from [baseUrl]".
  final String filesBaseUrl;

  const AppSettings({
    this.baseUrl = defaultBaseUrl,
    this.apiKey = '',
    this.themeMode = AppThemeMode.system,
    this.dynamicColor = false,
    this.systemInstructions = '',
    this.toolProgress = true,
    this.assistantName = 'Hermes',
    this.assistantAvatarPath = '',
    this.filesBaseUrl = '',
  });

  bool get isConfigured => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  /// Effective file-service base URL (explicit override, else derived from [baseUrl]).
  String get effectiveFilesBaseUrl {
    final explicit = filesBaseUrl.trim();
    if (explicit.isNotEmpty) return explicit;
    return deriveFilesBaseUrl(baseUrl);
  }

  /// Given an API base URL, guess the companion file-service base URL. The server
  /// exposes `<origin>/hermes-api` and `<origin>/hermes-files`, so we swap that
  /// suffix; otherwise we append `/hermes-files`.
  static String deriveFilesBaseUrl(String baseUrl) {
    var cut = baseUrl.trim();
    while (cut.endsWith('/')) {
      cut = cut.substring(0, cut.length - 1);
    }
    if (cut.isEmpty) return '';
    for (final suffix in ['/hermes-api', '/api']) {
      if (cut.endsWith(suffix)) {
        return '${cut.substring(0, cut.length - suffix.length)}/hermes-files';
      }
    }
    return '$cut/hermes-files';
  }

  AppSettings copyWith({
    String? baseUrl,
    String? apiKey,
    AppThemeMode? themeMode,
    bool? dynamicColor,
    String? systemInstructions,
    bool? toolProgress,
    String? assistantName,
    String? assistantAvatarPath,
    String? filesBaseUrl,
  }) =>
      AppSettings(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        themeMode: themeMode ?? this.themeMode,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        systemInstructions: systemInstructions ?? this.systemInstructions,
        toolProgress: toolProgress ?? this.toolProgress,
        assistantName: assistantName ?? this.assistantName,
        assistantAvatarPath: assistantAvatarPath ?? this.assistantAvatarPath,
        filesBaseUrl: filesBaseUrl ?? this.filesBaseUrl,
      );
}

/// SharedPreferences-backed settings store with a broadcast [settings] stream and
/// synchronous in-memory mirrors so interceptors can read the current config
/// without awaiting.
class SettingsRepository {
  static const _keyBaseUrl = 'base_url';
  static const _keyApiKey = 'api_key';
  static const _keyTheme = 'theme_mode';
  static const _keyDynamicColor = 'dynamic_color';
  static const _keySystemInstructions = 'system_instructions';
  static const _keyToolProgress = 'tool_progress';
  static const _keyAssistantName = 'assistant_name';
  static const _keyAssistantAvatar = 'assistant_avatar_path';
  static const _keyFilesBaseUrl = 'files_base_url';

  final SharedPreferences _prefs;
  final _controller = StreamController<AppSettings>.broadcast();

  /// In-memory mirrors so synchronous interceptors can read the current config.
  String cachedBaseUrl = AppSettings.defaultBaseUrl;
  String cachedApiKey = '';
  String cachedFilesBaseUrl =
      AppSettings.deriveFilesBaseUrl(AppSettings.defaultBaseUrl);

  SettingsRepository(this._prefs) {
    _emit();
    _controller.stream.listen((s) {
      cachedBaseUrl = s.baseUrl;
      cachedApiKey = s.apiKey;
      cachedFilesBaseUrl = s.effectiveFilesBaseUrl;
    });
  }

  static Future<SettingsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepository(prefs);
  }

  AppSettings get _current => AppSettings(
        baseUrl: _prefs.getString(_keyBaseUrl) ?? AppSettings.defaultBaseUrl,
        apiKey: _prefs.getString(_keyApiKey) ?? '',
        themeMode: AppThemeModeWire.fromWire(_prefs.getString(_keyTheme)),
        dynamicColor: _prefs.getBool(_keyDynamicColor) ?? false,
        systemInstructions: _prefs.getString(_keySystemInstructions) ?? '',
        toolProgress: _prefs.getBool(_keyToolProgress) ?? true,
        assistantName:
            (_prefs.getString(_keyAssistantName) ?? '').trim().isNotEmpty
                ? _prefs.getString(_keyAssistantName)!
                : 'Hermes',
        assistantAvatarPath: _prefs.getString(_keyAssistantAvatar) ?? '',
        filesBaseUrl: _prefs.getString(_keyFilesBaseUrl) ?? '',
      );

  void _emit() {
    final s = _current;
    cachedBaseUrl = s.baseUrl;
    cachedApiKey = s.apiKey;
    cachedFilesBaseUrl = s.effectiveFilesBaseUrl;
    _controller.add(s);
  }

  Stream<AppSettings> get settings => _controller.stream;

  AppSettings snapshot() => _current;

  // Setters also refresh the synchronous mirrors, so a request issued right
  // after saving (e.g. "测试连接") can't race the persist -> stream round trip.
  Future<void> setBaseUrl(String value) async {
    final trimmed = value.trim();
    await _prefs.setString(_keyBaseUrl, trimmed);
    cachedBaseUrl = trimmed;
    final explicit = (_prefs.getString(_keyFilesBaseUrl) ?? '').trim();
    cachedFilesBaseUrl =
        explicit.isNotEmpty ? explicit : AppSettings.deriveFilesBaseUrl(trimmed);
    _emit();
  }

  Future<void> setApiKey(String value) async {
    final trimmed = value.trim();
    await _prefs.setString(_keyApiKey, trimmed);
    cachedApiKey = trimmed;
    _emit();
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    await _prefs.setString(_keyTheme, value.wireName);
    _emit();
  }

  Future<void> setDynamicColor(bool value) async {
    await _prefs.setBool(_keyDynamicColor, value);
    _emit();
  }

  Future<void> setSystemInstructions(String value) async {
    await _prefs.setString(_keySystemInstructions, value);
    _emit();
  }

  Future<void> setToolProgress(bool value) async {
    await _prefs.setBool(_keyToolProgress, value);
    _emit();
  }

  Future<void> setAssistantName(String value) async {
    await _prefs.setString(_keyAssistantName, value.trim());
    _emit();
  }

  Future<void> setAssistantAvatarPath(String value) async {
    await _prefs.setString(_keyAssistantAvatar, value.trim());
    _emit();
  }

  Future<void> setFilesBaseUrl(String value) async {
    final trimmed = value.trim();
    await _prefs.setString(_keyFilesBaseUrl, trimmed);
    cachedFilesBaseUrl = trimmed.isNotEmpty
        ? trimmed
        : AppSettings.deriveFilesBaseUrl(cachedBaseUrl);
    _emit();
  }

  void dispose() => _controller.close();
}
