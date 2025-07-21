import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ThemeModeNotifier() : super(ThemeMode.light);

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
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
