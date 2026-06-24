import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soc_app/data/ai_config_service.dart';
import 'package:soc_app/presentation/providers/ai_config_provider.dart';

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

  String _presetId = 'deepseek';
  bool _enableThinking = false;
  String _reasoningEffort = 'high';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
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
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _onPresetChanged(String presetId) {
    final preset =
        kAiProviderPresets.firstWhere((p) => p.id == presetId,
            orElse: () => kAiProviderPresets.last);
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
    final service = ref.read(aiConfigProvider);
    await service.writeApiKey(_keyCtrl.text);
    await service.writePresetId(_presetId);
    await service.writeBaseUrl(_urlCtrl.text);
    await service.writeModel(_modelCtrl.text);
    await service.writeEnableThinking(_enableThinking);
    await service.writeReasoningEffort(_reasoningEffort);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _clear() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已清除')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPreset =
        kAiProviderPresets.firstWhere((p) => p.id == _presetId,
            orElse: () => kAiProviderPresets.last);

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
                        Text('AI 服务配置',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge),
                        const SizedBox(height: 16),
                        DropdownMenu<String>(
                          initialSelection: _presetId,
                          label: const Text('服务提供商'),
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                          ),
                          dropdownMenuEntries: kAiProviderPresets
                              .map((p) => DropdownMenuEntry(
                                  value: p.id,
                                  label: p.displayName))
                              .toList(),
                          onSelected: (v) {
                            if (v != null) _onPresetChanged(v);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'API 地址',
                            hintText:
                                'https://api.deepseek.com',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _keyCtrl,
                          obscureText: _obscureKey,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureKey
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscureKey = !_obscureKey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _modelCtrl,
                          decoration: const InputDecoration(
                            labelText: '模型',
                            hintText: 'deepseek-v4-pro',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (currentPreset.supportsThinking) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          Text('思考模式',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('启用思考模式'),
                            subtitle: Text(
                                _enableThinking
                                    ? '模型在回答前进行深度推理'
                                    : '关闭后使用快速模式',
                                style: const TextStyle(
                                    fontSize: 12)),
                            value: _enableThinking,
                            onChanged: (v) => setState(
                                () => _enableThinking = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_enableThinking)
                            DropdownMenu<String>(
                              initialSelection: _reasoningEffort,
                              label: const Text('推理强度'),
                              inputDecorationTheme: const InputDecorationTheme(
                                border: OutlineInputBorder(),
                              ),
                              dropdownMenuEntries: const [
                                DropdownMenuEntry(
                                    value: 'low',
                                    label: '低 (快速)'),
                                DropdownMenuEntry(
                                    value: 'medium',
                                    label: '中'),
                                DropdownMenuEntry(
                                    value: 'high',
                                    label: '高 (深度)'),
                              ],
                              onSelected: (v) {
                                if (v != null) {
                                  setState(() =>
                                      _reasoningEffort = v);
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
                        onPressed: _clear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('清除配置'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
