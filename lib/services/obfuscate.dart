import 'dart:convert';
import 'package:obfuscate/obfuscate.dart' as obfs;
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Map<String, String> obfuscationFA2Map = {};
Map<String, String> obfuscationFA1Map = {};
Map<String, String> obfuscationEN2Map = {};
Map<String, String> obfuscationEN1Map = {};

class Obfuscate {
  static Map<String, String> loadObfuscationMap(String prefix) {
    return Map.fromEntries(
      dotenv.env.entries.where((entry) => entry.key.startsWith(prefix)).map((
        entry,
      ) {
        var key = entry.key.substring(prefix.length).toLowerCase();
        var value = entry.value;
        if (value.contains(' ')) {
          debugPrint(
            'Warning: Substitution for ${entry.key} contains space; trimming.',
          );
          value = value.replaceAll(' ', '');
        }
        return MapEntry(key, value);
      }),
    );
  }

  static void setObfuscationFA2Map() {
    obfuscationFA2Map = loadObfuscationMap('OBF_FA2_');
    if (obfuscationFA2Map.isEmpty) {
      debugPrint('Warning: OBF_FA2 map is empty; obfuscation will be no-op.');
    }
  }

  static void setObfuscationFA1Map() {
    obfuscationFA1Map = loadObfuscationMap('OBF_FA1_');
    if (obfuscationFA1Map.isEmpty) {
      debugPrint('Warning: OBF_FA1 map is empty; obfuscation will be no-op.');
    }
  }

  static void setObfuscationEN2Map() {
    obfuscationEN2Map = loadObfuscationMap('OBF_EN2_');
    if (obfuscationEN2Map.isEmpty) {
      debugPrint('Warning: OBF_EN2 map is empty; obfuscation will be no-op.');
    }
  }

  static void setObfuscationEN1Map() {
    obfuscationEN1Map = loadObfuscationMap('OBF_EN1_');
    if (obfuscationEN1Map.isEmpty) {
      debugPrint('Warning: OBF_EN1 map is empty; obfuscation will be no-op.');
    }
  }

  static void setAllMaps() {
    setObfuscationFA1Map();
    setObfuscationFA2Map();
    setObfuscationEN1Map();
    setObfuscationEN2Map();
  }

  static String obfuscateText(
    String text,
    Map<String, String> obfuscationMap, {
    bool preserveUnmapped = false,
    bool preserveCase = false,
  }) {
    return obfs.Obfuscate.obfuscateWithMap(text, obfuscationMap);
  }

  static String deobfuscateText(
    String text,
    Map<String, String> obfuscationMap,
  ) {
    return obfs.Obfuscate.deobfuscateWithMap(text, obfuscationMap);
  }

  // Base64 obfuscation
  static String obfuscateBase64(String text) {
    final bytes = utf8.encode(text);
    return base64.encode(bytes);
  }

  static String deobfuscateBase64(String encodedText) {
    try {
      final bytes = base64.decode(encodedText);
      return utf8.decode(bytes);
    } catch (e) {
      return encodedText; // Return original if decoding fails
    }
  }

  // ROT13 obfuscation
  static String obfuscateROT13(String text) {
    return obfs.Obfuscate.obfuscateROT13(text);
  }

  static String deobfuscateROT13(String text) {
    return obfuscateROT13(text);
  }

  //XOR obfuscation with key
  static String obfuscateXOR(String text, int key) {
    return obfs.Obfuscate.obfuscateXOR(text, key);
  }

  static String deobfuscateXOR(String text, int key) {
    return obfuscateXOR(text, key);
  }

  // Reverse string obfuscation
  static String obfuscateReverse(String text) {
    return obfs.Obfuscate.obfuscateReverse(text);
  }

  static String deobfuscateReverse(String text) {
    return obfuscateReverse(text);
  }
}
