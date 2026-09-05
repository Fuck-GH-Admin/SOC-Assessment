import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:soc_app/core/theme/theme_provider.dart';
import 'package:soc_app/data/ai_config_service.dart';
import 'package:soc_app/presentation/pages/settings/manual_viewer_page.dart';
import 'package:soc_app/presentation/providers/ai_config_provider.dart';

final _kVersion = '1.1.5 (build 3)';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _loading = true;
  bool _saving = false;
  bool _clearing = false;

  String _presetId = 'deepseek';
  bool _enableThinking = false;
  String _reasoningEffort = 'high';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final service = ref.read(aiConfigProvider);
      final presetId = await service.readPresetId();
      final baseUrl = await service.readBaseUrl();
      final model = await service.readModel();
      final key = await service.readApiKey();
      final enableThinking = await service.readEnableThinking();
      final reasoningEffort = await service.readReasoningEffort();
      if (!mounted) return;
      setState(() {
        _presetId = presetId;
        _urlCtrl.text = baseUrl;
        _modelCtrl.text = model;
        _keyCtrl.text = key ?? '';
        _enableThinking = enableThinking;
        _reasoningEffort = reasoningEffort;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('配置读取失败：$e');
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _onPresetChanged(String presetId) {
    final preset = kAiProviderPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => kAiProviderPresets.first,
    );
    setState(() {
      _presetId = presetId;
      _urlCtrl.text = preset.baseUrl;
      _modelCtrl.text = preset.defaultModel;
      if (!preset.supportsThinking) {
        _enableThinking = false;
      }
    });
  }

  Future<void> _save() async {
    final baseUrl = _urlCtrl.text.trim();
    final apiKey = _keyCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      _showMessage('请输入有效的 HTTP/HTTPS API 地址');
      return;
    }
    final selectedPreset = kAiProviderPresets.firstWhere(
      (p) => p.id == _presetId,
      orElse: () => kAiProviderPresets.first,
    );
    if (apiKey.isEmpty && selectedPreset.apiKeyRequired) {
      _showMessage('API Key 不能为空');
      return;
    }
    if (model.isEmpty) {
      _showMessage('模型名称不能为空');
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(aiConfigProvider);
      await service.writePresetId(_presetId);
      await service.writeBaseUrl(baseUrl);
      await service.writeModel(model);
      await service.writeApiKey(apiKey);
      await service.writeEnableThinking(_enableThinking);
      await service.writeReasoningEffort(_reasoningEffort);
      if (mounted) {
        _showMessage('配置已保存');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMessage('配置保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    try {
      final service = ref.read(aiConfigProvider);
      await service.clearAll();
      if (mounted) {
        final preset = kAiProviderPresets.first;
        setState(() {
          _presetId = preset.id;
          _urlCtrl.text = preset.baseUrl;
          _modelCtrl.text = preset.defaultModel;
          _keyCtrl.text = '';
          _enableThinking = false;
          _reasoningEffort = 'high';
        });
        _showMessage('配置已清除');
      }
    } catch (e) {
      _showMessage('配置清除失败：$e');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openManual(String title, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualViewerPage(
          title: title,
          assetPath: 'assets/manual/$fileName',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPreset = kAiProviderPresets.firstWhere(
      (p) => p.id == _presetId,
      orElse: () => kAiProviderPresets.first,
    );
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentSeedColor = ref.watch(seedColorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 服务配置',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        DropdownMenu<String>(
                          key: ValueKey(_presetId),
                          initialSelection: _presetId,
                          label: const Text('服务提供商'),
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                          ),
                          dropdownMenuEntries: kAiProviderPresets
                              .map(
                                (p) => DropdownMenuEntry(
                                  value: p.id,
                                  label: p.displayName,
                                ),
                              )
                              .toList(),
                          onSelected: (v) {
                            if (v != null) _onPresetChanged(v);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'API 基础地址或完整接口地址',
                            hintText: 'https://api.deepseek.com',
                            helperText:
                                '可填写基础地址，也可直接填写以 /chat/completions 结尾的地址',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _keyCtrl,
                          obscureText: _obscureKey,
                          decoration: InputDecoration(
                            labelText: currentPreset.apiKeyRequired
                                ? 'API Key'
                                : 'API Key（可选）',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureKey
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureKey = !_obscureKey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _modelCtrl,
                          decoration: const InputDecoration(
                            labelText: '模型',
                            hintText: '填写服务商支持的模型 ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (currentPreset.supportsThinking) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          Text(
                            '思考模式',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('启用思考模式'),
                            subtitle: Text(
                              _enableThinking ? '模型在回答前进行深度推理' : '关闭后使用快速模式',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _enableThinking,
                            onChanged: (v) =>
                                setState(() => _enableThinking = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_enableThinking)
                            DropdownMenu<String>(
                              key: ValueKey(_reasoningEffort),
                              initialSelection: _reasoningEffort,
                              label: const Text('推理强度'),
                              inputDecorationTheme: const InputDecorationTheme(
                                border: OutlineInputBorder(),
                              ),
                              dropdownMenuEntries: const [
                                DropdownMenuEntry(
                                  value: 'low',
                                  label: '低 (快速)',
                                ),
                                DropdownMenuEntry(value: 'medium', label: '中'),
                                DropdownMenuEntry(
                                  value: 'high',
                                  label: '高 (深度)',
                                ),
                              ],
                              onSelected: (v) {
                                if (v != null) {
                                  setState(() => _reasoningEffort = v);
                                }
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving || _clearing ? null : _clear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('清除配置'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving || _clearing ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('保存'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主题',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '配色方案',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(kColorPresets.length, (i) {
                            final preset = kColorPresets[i];
                            final selected =
                                preset.color.toARGB32() ==
                                currentSeedColor.toARGB32();
                            return GestureDetector(
                              onTap: () => ref
                                  .read(seedColorProvider.notifier)
                                  .setColor(i),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: preset.color,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        Text(
                          '外观模式',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('跟随系统'),
                              icon: Icon(Icons.brightness_auto),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('浅色'),
                              icon: Icon(Icons.light_mode),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('深色'),
                              icon: Icon(Icons.dark_mode),
                            ),
                          ],
                          selected: {currentThemeMode},
                          onSelectionChanged: (v) => ref
                              .read(themeModeProvider.notifier)
                              .setMode(v.first),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '帮助',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.rocket_launch_outlined),
                          title: const Text('快速入门'),
                          subtitle: const Text('用一次完整流程完成第一次评估'),
                          onTap: () => _openManual('快速入门', 'quick-start.md'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.menu_book_outlined),
                          title: const Text('完整用户指南'),
                          subtitle: const Text('页面、参数、结果、历史与故障处理'),
                          onTap: () => _openManual('完整用户指南', 'user-guide.md'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.science_outlined),
                          title: const Text('科学口径与附录'),
                          subtitle: const Text('数据来源、公式、单位、版本和限制'),
                          onTap: () =>
                              _openManual('科学口径与附录', 'scientific-basis.md'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.help_outline),
                          title: const Text('常见问题'),
                          subtitle: const Text('操作和结果解释中的高频问题'),
                          onTap: () => _openManual('常见问题', 'faq.md'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.translate),
                          title: const Text('术语表'),
                          subtitle: const Text('SOC、CK、碳库等专业词汇'),
                          onTap: () => _openManual('术语表', 'glossary.md'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '关于',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.info_outline),
                          title: const Text('碳盾 · SOC-Shield'),
                          subtitle: Text('v$_kVersion'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bug_report_outlined),
                          title: const Text('反馈问题 / 查看源码'),
                          subtitle: const Text(
                            'github.com/Fuck-GH-Admin/SOC-Assessment',
                          ),
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://github.com/Fuck-GH-Admin/SOC-Assessment/issues',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
