import 'package:qrypt/models/Qrypt.dart';

import '../models/compression_method.dart';
import '../models/encryption_method.dart';
import '../models/obfuscation_method.dart';
import 'crypto.dart';
import 'obfuscate.dart';

class TagManager{
  static Qrypt setTag(Qrypt q){
    String tag = q.getCompressionMethod().name+q.getEncryptionMethod().name+q.getObfuscationMethod().name;
    q.tag = Crypto.generateTagHash(tag);
    // q.tag += ':'; //no longer needed since its checking with startsWith
    return q;
  }

  static final Set<String> knownTags = {};

  static void loadAllTags() {
    for (var comp in CompressionMethod.values) {
      for (var enc in EncryptionMethod.values) {
        for (var obf in ObfuscationMethod.values) {
          final rawTag = '${comp.name}${enc.name}${obf.name}';
          final tagHash = Crypto.generateTagHash(rawTag);

          String obfsTag = switch (obf) {
            ObfuscationMethod.none => tagHash,
            ObfuscationMethod.fa1 =>
                Obfuscate.obfuscateText(tagHash, obfuscationFA1Map),
            ObfuscationMethod.fa2 =>
                Obfuscate.obfuscateText(tagHash, obfuscationFA2Map),
          };

          knownTags.add(obfsTag);
        }
      }
    }

    print('Loaded ${knownTags.length} tag combinations');
  }

  static void initializeTags() {
    knownTags.clear();
    loadAllTags();
  }

  /// Returns true if this string starts with a known obfuscated tag
  static bool hasKnownTagPrefix(String text) {
    for (final tag in knownTags) {
      if (text.startsWith(tag)) return true;
    }
    return false;
  }

  ///Returns the tag if matched
  static String? matchedTag(String text) {
    for (final tag in knownTags) {
      print('checking tag $tag');
      if (text.startsWith(tag)) return tag;
    }
    return null;
  }

  static ({
  CompressionMethod compression,
  EncryptionMethod encryption,
  ObfuscationMethod obfuscation
  })? getMethodsFromTag(String tag) {
    for (var comp in CompressionMethod.values) {
      for (var enc in EncryptionMethod.values) {
        for (var obf in ObfuscationMethod.values) {
          final raw = '${comp.name}${enc.name}${obf.name}';
          final hash = Crypto.generateTagHash(raw);

          final obfsTag = switch (obf) {
            ObfuscationMethod.none => hash,
            ObfuscationMethod.fa1 => Obfuscate.obfuscateText(hash, obfuscationFA1Map),
            ObfuscationMethod.fa2 => Obfuscate.obfuscateText(hash, obfuscationFA2Map),
          };

          if (tag.startsWith(obfsTag)) {
            return (
            compression: comp,
            encryption: enc,
            obfuscation: obf
            );
          }
        }
      }
    }

    return null; // No match found
  }

}

