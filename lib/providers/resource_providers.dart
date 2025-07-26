import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppMode { encrypt, decrypt }

final appModeProvider = StateProvider<AppMode>((ref) => AppMode.encrypt);

final primaryColorProvider = Provider<Color>((ref) {
  final mode = ref.watch(appModeProvider);
  return mode == AppMode.encrypt ? Colors.blue : Colors.green;
});

final currentTextControllerProvider = StateProvider<TextEditingController>(
  (ref) => TextEditingController(),
);

final isDarkModeProvider = StateProvider<bool>((ref) => false);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeKey = 'app_theme_mode';
  static const _storage = FlutterSecureStorage();

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final savedTheme = await _storage.read(key: _themeKey);
      if (savedTheme != null) {
        switch (savedTheme) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'system':
            state = ThemeMode.system;
            break;
          default:
            state = ThemeMode.system;
        }
      }
    } catch (e) {
      state = ThemeMode.light;
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    try {
      String themeString;
      switch (mode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.system:
          themeString = 'system';
          break;
      }
      await _storage.write(key: _themeKey, value: themeString);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  void toggleTheme() {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    _saveTheme(newMode);
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    _saveTheme(mode);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

extension ThemeModeLabel on ThemeMode {
  String get label {
    switch (this) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}
