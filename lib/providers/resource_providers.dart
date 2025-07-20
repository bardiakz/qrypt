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
