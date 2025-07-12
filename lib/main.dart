import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:es_compression/lz4.dart';
import 'package:es_compression/brotli.dart';
import 'package:path/path.dart' as path;

void main() async{
  await dotenv.load();
  Obfuscate.setObfuscationFA2Map();
  Obfuscate.setObfuscationFA1Map();
  final basePath = path.join(Directory.current.path, 'native_libs');

  String lz4LibPath;
  if (Platform.isWindows) {
    lz4LibPath = path.join(basePath, 'eslz4-win64.dll');
  } else if (Platform.isLinux) {
    lz4LibPath = path.join(basePath, 'eslz4-linux64.so');
  } else if (Platform.isMacOS) {
    lz4LibPath = path.join(basePath, 'eslz4-mac64.dylib');
  } else {
    throw UnsupportedError('Unsupported platform');
  }
  Lz4Codec.libraryPath = lz4LibPath;

  String brotliLibPath;
  if (Platform.isWindows) {
    brotliLibPath = path.join(basePath, 'esbrotli-win64.dll');
  } else if (Platform.isLinux) {
    brotliLibPath = path.join(basePath, 'esbrotli-linux64.so');
  } else if (Platform.isMacOS) {
    brotliLibPath = path.join(basePath, 'esbrotli-mac64.dylib');
  } else {
    throw UnsupportedError('Unsupported platform');
  }
  BrotliCodec.libraryPath = brotliLibPath;
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

