import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/prefs/settings_repository.dart';
import '../../di.dart';
import 'settings_view_model.dart';

class SettingsRoute extends StatefulWidget {
  final VoidCallback onBack;

  const SettingsRoute({super.key, required this.onBack});

  @override
  State<SettingsRoute> createState() => _SettingsRouteState();
}

class _SettingsRouteState extends State<SettingsRoute> {
  late final SettingsViewModel _viewModel = SettingsViewModel(
    settingsRepository: Di.settings,
    api: Di.api,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    final path = file?.path;
    if (path != null) {
      await _viewModel.setAssistantAvatar(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final settings = _viewModel.settings;
        return SettingsScreen(
          baseUrl: settings.baseUrl,
          apiKey: settings.apiKey,
          filesBaseUrl:
              settings.filesBaseUrl.isEmpty ? settings.effectiveFilesBaseUrl : settings.filesBaseUrl,
          themeMode: settings.themeMode,
          dynamicColor: settings.dynamicColor,
          systemInstructions: settings.systemInstructions,
          toolProgress: settings.toolProgress,
          assistantName: settings.assistantName,
          assistantAvatarPath: settings.assistantAvatarPath,
          test: _viewModel.test,
          onBack: widget.onBack,
          onSaveConnection: (base, key) {
            _viewModel.saveConnection(base, key);
            _viewModel.clearTest();
          },
          onTestConnection: _viewModel.testConnection,
          onSaveInstructions: _viewModel.saveSystemInstructions,
          onThemeMode: _viewModel.setThemeMode,
          onDynamicColor: _viewModel.setDynamicColor,
          onToolProgress: _viewModel.setToolProgress,
          onAssistantName: _viewModel.setAssistantName,
          onPickAvatar: _pickAvatar,
          onClearAvatar: _viewModel.clearAssistantAvatar,
          onSaveFilesBaseUrl: _viewModel.setFilesBaseUrl,
          onClearTest: _viewModel.clearTest,
        );
      },
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String baseUrl;
  final String apiKey;
  final String filesBaseUrl;
  final AppThemeMode themeMode;
  final bool dynamicColor;
  final String systemInstructions;
  final bool toolProgress;
  final String assistantName;
  final String assistantAvatarPath;
  final ConnectionTest test;
  final VoidCallback onBack;
  final void Function(String, String) onSaveConnection;
  final void Function(String, String) onTestConnection;
  final ValueChanged<String> onSaveInstructions;
  final ValueChanged<AppThemeMode> onThemeMode;
  final ValueChanged<bool> onDynamicColor;
  final ValueChanged<bool> onToolProgress;
  final ValueChanged<String> onAssistantName;
  final VoidCallback onPickAvatar;
  final VoidCallback onClearAvatar;
  final ValueChanged<String> onSaveFilesBaseUrl;
  final VoidCallback onClearTest;

  const SettingsScreen({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.filesBaseUrl,
    required this.themeMode,
    required this.dynamicColor,
    required this.systemInstructions,
    required this.toolProgress,
    required this.assistantName,
    required this.assistantAvatarPath,
    required this.test,
    required this.onBack,
    required this.onSaveConnection,
    required this.onTestConnection,
    required this.onSaveInstructions,
    required this.onThemeMode,
    required this.onDynamicColor,
    required this.onToolProgress,
    required this.onAssistantName,
    required this.onPickAvatar,
    required this.onClearAvatar,
    required this.onSaveFilesBaseUrl,
    required this.onClearTest,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _baseUrlField;
  late TextEditingController _apiKeyField;
  late TextEditingController _filesUrlField;
  late TextEditingController _instructionsField;
  late TextEditingController _assistantNameField;
  bool _keyVisible = false;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    _baseUrlField = TextEditingController(text: widget.baseUrl);
    _apiKeyField = TextEditingController(text: widget.apiKey);
    _filesUrlField = TextEditingController(text: widget.filesBaseUrl);
    _instructionsField = TextEditingController(text: widget.systemInstructions);
    _assistantNameField = TextEditingController(text: widget.assistantName);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.baseUrl != oldWidget.baseUrl &&
        widget.baseUrl != _baseUrlField.text) {
      _baseUrlField.text = widget.baseUrl;
    }
    if (widget.apiKey != oldWidget.apiKey && widget.apiKey != _apiKeyField.text) {
      _apiKeyField.text = widget.apiKey;
    }
    if (widget.filesBaseUrl != oldWidget.filesBaseUrl &&
        widget.filesBaseUrl != _filesUrlField.text) {
      _filesUrlField.text = widget.filesBaseUrl;
    }
    if (widget.systemInstructions != oldWidget.systemInstructions &&
        widget.systemInstructions != _instructionsField.text) {
      _instructionsField.text = widget.systemInstructions;
    }
    if (widget.assistantName != oldWidget.assistantName &&
        widget.assistantName != _assistantNameField.text) {
      _assistantNameField.text = widget.assistantName;
    }
  }

  @override
  void dispose() {
    _baseUrlField.dispose();
    _apiKeyField.dispose();
    _filesUrlField.dispose();
    _instructionsField.dispose();
    _assistantNameField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '返回',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('服务器'),
            TextField(
              controller: _baseUrlField,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://example.com/hermes-api',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _apiKeyField,
              obscureText: !_keyVisible,
              decoration: InputDecoration(
                labelText: 'API Key',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _keyVisible = !_keyVisible),
                  icon: Icon(_keyVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: () => widget.onSaveConnection(
                      _baseUrlField.text, _apiKeyField.text),
                  child: const Text('保存'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => widget.onTestConnection(
                      _baseUrlField.text, _apiKeyField.text),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.test is ConnectionTestLoading) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Text('测试连接'),
                    ],
                  ),
                ),
              ],
            ),
            switch (widget.test) {
              ConnectionTestSuccess(:final models, :final insecureUrl) =>
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ 连接成功，模型：${models.isEmpty ? "(无)" : models.join(", ")}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.primary),
                    ),
                    if (insecureUrl)
                      Text(
                        '⚠️ 当前使用明文 http，凭据与对话内容可能被窃听，建议使用 https。',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                  ],
                ),
              ConnectionTestFailure(:final message) => Text(
                  '❌ $message',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              _ => const SizedBox.shrink(),
            },
            const SizedBox(height: 4),
            TextField(
              controller: _filesUrlField,
              decoration: const InputDecoration(
                labelText: '文件服务 Base URL',
                hintText: 'https://example.com/hermes-files',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 6),
            Text(
              '用于图片/文件双向传输，留空则自动从 Base URL 推导。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _filesUrlField.text == widget.filesBaseUrl
                  ? null
                  : () => widget.onSaveFilesBaseUrl(_filesUrlField.text),
              child: const Text('保存文件服务地址'),
            ),
            const SizedBox(height: 6),
            const SectionTitle('外观'),
            Text(
              '主题',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in AppThemeMode.values)
                  FilterChip(
                    selected: widget.themeMode == mode,
                    onSelected: (_) => widget.onThemeMode(mode),
                    label: Text(switch (mode) {
                      AppThemeMode.system => '跟随系统',
                      AppThemeMode.light => '浅色',
                      AppThemeMode.dark => '深色',
                    }),
                  ),
              ],
            ),
            SettingSwitch(
              title: '动态取色 (Material You)',
              subtitle: 'Android 12+ 使用系统壁纸配色（Windows 不支持）',
              checked: widget.dynamicColor,
              onChange: widget.onDynamicColor,
            ),
            const SizedBox(height: 6),
            const SectionTitle('对话'),
            SettingSwitch(
              title: '显示工具调用进度',
              subtitle: '展示 tool.started / tool.completed',
              checked: widget.toolProgress,
              onChange: widget.onToolProgress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instructionsField,
              decoration: const InputDecoration(
                labelText: '系统指令 (instructions)',
                hintText: '可选，作为每次任务的系统提示',
              ),
              minLines: 2,
              maxLines: 6,
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _instructionsField.text == widget.systemInstructions
                  ? null
                  : () => widget.onSaveInstructions(_instructionsField.text),
              child: const Text('保存系统指令'),
            ),
            const SizedBox(height: 6),
            const SectionTitle('助手'),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.assistantAvatarPath.trim().isNotEmpty &&
                          File(widget.assistantAvatarPath).existsSync()
                      ? Image.file(
                          File(widget.assistantAvatarPath),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.person_rounded,
                                  size: 34, color: scheme.onPrimary),
                        )
                      : Icon(Icons.person_rounded,
                          size: 34, color: scheme.onPrimary),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton(
                      onPressed: widget.onPickAvatar,
                      child: const Text('选择头像'),
                    ),
                    TextButton(
                      onPressed: widget.assistantAvatarPath.trim().isEmpty
                          ? null
                          : widget.onClearAvatar,
                      child: const Text('恢复默认'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _assistantNameField,
              decoration: const InputDecoration(
                labelText: '助手名称',
                hintText: 'Hermes',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed:
                  _assistantNameField.text.trim() == widget.assistantName.trim()
                      ? null
                      : () => widget.onAssistantName(_assistantNameField.text),
              child: const Text('保存名称'),
            ),
            const SizedBox(height: 6),
            const SectionTitle('关于'),
            const Text('Hermes v1.0.0'),
            Text(
              '使用 Hermes Runs API：异步发起、断线可恢复、完成即通知。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class SettingSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool checked;
  final ValueChanged<bool> onChange;

  const SettingSwitch({
    super.key,
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Switch(value: checked, onChanged: onChange),
      ],
    );
  }
}
