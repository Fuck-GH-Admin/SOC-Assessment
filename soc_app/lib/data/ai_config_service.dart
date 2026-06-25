import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiProviderPreset {
  final String id;
  final String displayName;
  final String baseUrl;
  final String defaultModel;
  final bool supportsThinking;
  final Map<String, dynamic>? extraBody;

  const AiProviderPreset({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.defaultModel,
    this.supportsThinking = false,
    this.extraBody,
  });
}

const kAiProviderPresets = [
  AiProviderPreset(
    id: 'deepseek',
    displayName: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    defaultModel: 'deepseek-v4-flash',
    supportsThinking: true,
    extraBody: {'thinking': {'type': 'enabled'}},
  ),
  AiProviderPreset(
    id: 'openai',
    displayName: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4.1',
  ),
  AiProviderPreset(
    id: 'groq',
    displayName: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'qwen/qwen3.6-27b',
  ),
  AiProviderPreset(
    id: 'openrouter',
    displayName: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'deepseek/deepseek-v4-flash',
  ),
  AiProviderPreset(
    id: 'custom',
    displayName: '自定义',
    baseUrl: '',
    defaultModel: '',
  ),
];

class AiConfigService {
  static const _keyApiKey = 'ai_api_key';
  static const _keyBaseUrl = 'ai_base_url';
  static const _keyApiModel = 'ai_api_model';
  static const _keyPresetId = 'ai_preset_id';
  static const _keyEnableThinking = 'ai_enable_thinking';
  static const _keyReasoningEffort = 'ai_reasoning_effort';
  static const _defaultPresetId = 'deepseek';
  static const _defaultReasoningEffort = 'high';

  final FlutterSecureStorage _secure;

  AiConfigService({FlutterSecureStorage? secure})
      : _secure = secure ??
            const FlutterSecureStorage(
              wOptions:
                  WindowsOptions(useBackwardCompatibility: false),
            );

  // --- API Key (secure storage) ---

  Future<String?> readApiKey() async {
    try {
      return await _secure.read(key: _keyApiKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeApiKey(String value) async {
    try {
      if (value.isEmpty) {
        await _secure.delete(key: _keyApiKey);
      } else {
        await _secure.write(key: _keyApiKey, value: value);
      }
    } catch (_) {}
  }

  Future<bool> hasApiKey() async {
    final key = await readApiKey();
    return key != null && key.isNotEmpty;
  }

  // --- Preset ---

  Future<String> readPresetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPresetId) ?? _defaultPresetId;
  }

  Future<void> writePresetId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty || value == _defaultPresetId) {
      await prefs.remove(_keyPresetId);
    } else {
      await prefs.setString(_keyPresetId, value);
    }
  }

  Future<AiProviderPreset> readPreset() async {
    final id = await readPresetId();
    return kAiProviderPresets.firstWhere((p) => p.id == id,
        orElse: () => kAiProviderPresets.last);
  }

  // --- Base URL ---

  Future<String> readBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyBaseUrl);
    if (saved != null && saved.isNotEmpty) return saved;
    final preset = await readPreset();
    return preset.baseUrl;
  }

  Future<void> writeBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final preset = await readPreset();
    if (value.isEmpty || value == preset.baseUrl) {
      await prefs.remove(_keyBaseUrl);
    } else {
      await prefs.setString(_keyBaseUrl, value);
    }
  }

  // --- Model ---

  Future<String> readModel() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyApiModel);
    if (saved != null && saved.isNotEmpty) return saved;
    final preset = await readPreset();
    return preset.defaultModel;
  }

  Future<void> writeModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final preset = await readPreset();
    if (value.isEmpty || value == preset.defaultModel) {
      await prefs.remove(_keyApiModel);
    } else {
      await prefs.setString(_keyApiModel, value);
    }
  }

  // --- Thinking ---

  Future<bool> readEnableThinking() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnableThinking) ?? false;
  }

  Future<void> writeEnableThinking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableThinking, value);
  }

  Future<String> readReasoningEffort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyReasoningEffort) ??
        _defaultReasoningEffort;
  }

  Future<void> writeReasoningEffort(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReasoningEffort, value);
  }

  // --- Bulk ---

  Future<void> clearAll() async {
    try {
      await _secure.delete(key: _keyApiKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBaseUrl);
    await prefs.remove(_keyApiModel);
    await prefs.remove(_keyPresetId);
    await prefs.remove(_keyEnableThinking);
    await prefs.remove(_keyReasoningEffort);
  }
}
