import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/providers/resource_providers.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() async {
  await dotenv.load();
  Obfuscate.setAllMaps();
  if (!(Platform.isAndroid || Platform.isIOS)) {
    Compression.setNativeLibPaths();
  }
  TagManager.initializeTags();
  // if (kDebugMode) {
  //   final storage = FlutterSecureStorage();
  //   await storage.deleteAll();
  // }

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Qrypt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        // switchTheme: SwitchThemeData(
        //   thumbColor: WidgetStateProperty.all(Colors.white),
        //   trackColor: WidgetStateProperty.resolveWith((states) {
        //     if (states.contains(WidgetState.selected)) {
        //       return Colors.blue;
        //     }
        //     return Colors.grey.shade400;
        //   }),
        // ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: const EncryptionPage(),
    );
  }
}
