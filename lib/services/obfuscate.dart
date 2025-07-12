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
    // Split by first colon to preserve the tag
    final parts = text.split(':');
    if (parts.length < 2) {
      return text; // Return original text if no colon found
    }

    final tag = parts[0];
    // Join remaining parts back with colon in case there are multiple colons
    final obfuscatedContent = parts.sublist(1).join(':');

    // Create reverse mapping
    Map<String, String> reverseMap = obfuscationMap.map(
      (key, value) => MapEntry(value, key),
    );

    // Split by spaces and deobfuscate each word
    final deobfuscatedContent = obfuscatedContent
        .split(' ')
        .where((word) => word.isNotEmpty) // Filter out empty strings
        .map((word) => reverseMap[word] ?? word)
        .join(''); // Join without spaces

    return '$tag:$deobfuscatedContent';
  }
}
