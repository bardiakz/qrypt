import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Map<String, String> obfuscationFA2Map = {};
Map<String, String> obfuscationFA1Map = {};

class Obfuscate {
  static Map<String, String> loadObfuscationFA2Map() {
    return Map.fromEntries(
      dotenv.env.entries
          .where(
            (entry) => entry.key.startsWith("OBF_FA2_"),
          ) // Filter obfuscation keys
          .map(
            (entry) =>
                MapEntry(entry.key.substring(8).toLowerCase(), entry.value),
          ), // Remove "OBF_FA2_" prefix
    );
  }

  static Map<String, String> loadObfuscationFA1Map() {
    return Map.fromEntries(
      dotenv.env.entries
          .where(
            (entry) => entry.key.startsWith("OBF_FA1_"),
          ) // Filter obfuscation keys
          .map(
            (entry) =>
                MapEntry(entry.key.substring(8).toLowerCase(), entry.value),
          ), // Remove "OBF_FA2_" prefix
    );
  }

  static void setObfuscationFA2Map() {
    obfuscationFA2Map = loadObfuscationFA2Map();
  }

  static void setObfuscationFA1Map() {
    obfuscationFA1Map = loadObfuscationFA1Map();
  }

  static String obfuscateFA1Tag(String tag) {
    final obfuscatedTag = tag
        .split('')
        .map((char) => obfuscationFA1Map[char.toLowerCase()] ?? char)
        .join(''); //no space between words for tag
    return obfuscatedTag;
  }

  static String obfuscateTextWithTag(String text, Map<String, String> obfuscationMap) {
    // Split by first colon to preserve the tag
    final parts = text.split(':');
    if (parts.length < 2) {
      return text; // Return original text if no colon found
    }

    final tag = parts[0];
    // Join remaining parts back with colon in case there are multiple colons
    final contentToObfuscate = parts.sublist(1).join(':');

    // Obfuscate with spaces between words
    final obfuscatedContent = contentToObfuscate
        .split('')
        .map((char) => obfuscationMap[char.toLowerCase()] ?? char)
        .join(' '); // Add space between substituted words

    return '$tag:$obfuscatedContent';
  }
  static String obfuscateText(String text, Map<String, String> obfuscationMap) {

    // Join remaining parts back with colon in case there are multiple colons
    final contentToObfuscate = text;

    // Obfuscate with spaces between words
    final obfuscatedContent = contentToObfuscate
        .split('')
        .map((char) => obfuscationMap[char.toLowerCase()] ?? char)
        .join(' '); // Add space between substituted words

    return obfuscatedContent;
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
    return text.split('').map((char) {
      if (char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90) {
        // Uppercase A-Z
        return String.fromCharCode(((char.codeUnitAt(0) - 65 + 13) % 26) + 65);
      } else if (char.codeUnitAt(0) >= 97 && char.codeUnitAt(0) <= 122) {
        // Lowercase a-z
        return String.fromCharCode(((char.codeUnitAt(0) - 97 + 13) % 26) + 97);
      }
      return char; // Non-alphabetic characters unchanged
    }).join('');
  }

  static String deobfuscateROT13(String text) {
    return obfuscateROT13(text);
  }

  //XOR obfuscation with key
  static String obfuscateXOR(String text, int key) {
    return text.split('').map((char) {
      return String.fromCharCode(char.codeUnitAt(0) ^ key);
    }).join('');
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
