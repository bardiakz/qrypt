import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Map<String, String> obfuscationFA2Map = {};
Map<String, String> obfuscationFA1Map = {};
Map<String, String> obfuscationEN2Map = {};
Map<String, String> obfuscationEN1Map = {};

class Obfuscate {
  static Map<String, String> loadObfuscationMap(String prefix) {
    return Map.fromEntries(
      dotenv.env.entries
          .where(
            (entry) => entry.key.startsWith(prefix),
          ) // Filter obfuscation keys
          .map(
            (entry) =>
                MapEntry(entry.key.substring(8).toLowerCase(), entry.value),
          ), // Remove prefix
    );
  }

  static void setObfuscationFA2Map() {
    obfuscationFA2Map = loadObfuscationMap('OBF_FA2_');
  }

  static void setObfuscationFA1Map() {
    obfuscationFA1Map = loadObfuscationMap('OBF_FA1_');
  }

  static void setObfuscationEN2Map() {
    obfuscationEN2Map = loadObfuscationMap('OBF_EN2_');
  }

  static void setObfuscationEN1Map() {
    obfuscationEN1Map = loadObfuscationMap('OBF_EN1_');
  }

  static void setAllMaps() {
    setObfuscationFA1Map();
    setObfuscationFA2Map();
    setObfuscationEN1Map();
    setObfuscationEN2Map();
  }

  static String obfuscateText(String text, Map<String, String> obfuscationMap) {
    final contentToObfuscate = text;

    // Check if we're dealing with base64-like content
    bool isBase64Like = RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(text);

    if (isBase64Like) {
      // For base64 content, only obfuscate characters that exist in the map
      final obfuscatedContent = contentToObfuscate
          .split('')
          .where((char) => obfuscationMap.containsKey(char.toLowerCase()))
          .map((char) => obfuscationMap[char.toLowerCase()]!)
          .join(' ');

      // If no characters were obfuscated, return original
      return obfuscatedContent.isEmpty ? text : obfuscatedContent;
    } else {
      // Original logic for regular text
      final obfuscatedContent = contentToObfuscate
          .split('')
          .map((char) => obfuscationMap[char.toLowerCase()] ?? char)
          .join(' ');

      return obfuscatedContent;
    }
  }

  static String deobfuscateText(
    String text,
    Map<String, String> obfuscationMap,
  ) {
    // Create reverse mapping
    Map<String, String> reverseMap = obfuscationMap.map(
      (key, value) => MapEntry(value, key),
    );

    // Split by spaces and deobfuscate each word
    final deobfuscatedContent = text
        .split(' ')
        .where((word) => word.isNotEmpty) // Filter out empty strings
        .map((word) => reverseMap[word] ?? word)
        .join(''); // Join without spaces

    return deobfuscatedContent;
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
    return text
        .split('')
        .map((char) {
          if (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) {
            // Uppercase A-Z
            return String.fromCharCode(
              ((char.codeUnitAt(0) - 65 + 13) % 26) + 65,
            );
          } else if (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122) {
            // Lowercase a-z
            return String.fromCharCode(
              ((char.codeUnitAt(0) - 97 + 13) % 26) + 97,
            );
          }
          return char; // Non-alphabetic characters unchanged
        })
        .join('');
  }

  static String deobfuscateROT13(String text) {
    return obfuscateROT13(text);
  }

  //XOR obfuscation with key
  static String obfuscateXOR(String text, int key) {
    return text
        .split('')
        .map((char) {
          return String.fromCharCode(char.codeUnitAt(0) ^ key);
        })
        .join('');
  }

  static String deobfuscateXOR(String text, int key) {
    return obfuscateXOR(text, key);
  }

  // Reverse string obfuscation
  static String obfuscateReverse(String text) {
    return text.split('').reversed.join('');
  }

  static String deobfuscateReverse(String text) {
    return obfuscateReverse(text);
  }
}
