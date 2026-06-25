import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kColorPresets = [
  (name: '自然绿', color: Color(0xFF2E7D32)),
  (name: '深海蓝', color: Color(0xFF1565C0)),
  (name: '暖棕土', color: Color(0xFF5D4037)),
  (name: '蓝灰冷', color: Color(0xFF455A64)),
  (name: '紫灰雅', color: Color(0xFF4527A0)),
];

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('theme_mode') ?? 'system';
    final mode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString('theme_mode', value);
  }
}

class SeedColorNotifier extends Notifier<Color> {
  @override
  Color build() {
    _load();
    return kColorPresets[0].color;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('seed_color_index') ?? 0;
    if (index >= 0 && index < kColorPresets.length) {
      state = kColorPresets[index].color;
    }
  }

  Future<void> setColor(int index) async {
    if (index >= 0 && index < kColorPresets.length) {
      state = kColorPresets[index].color;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('seed_color_index', index);
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

final seedColorProvider =
    NotifierProvider<SeedColorNotifier, Color>(SeedColorNotifier.new);
