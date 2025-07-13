import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';


void main() async{
  await dotenv.load();
  Obfuscate.setObfuscationFA2Map();
  Obfuscate.setObfuscationFA1Map();
  if(!(Platform.isAndroid || Platform.isIOS)){
    Compression.setNativeLibPaths();
  }
  TagManager.initializeTags();

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Qrypt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
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
      home: const EncryptionPage(),
    );
  }
}

