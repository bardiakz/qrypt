import 'package:flutter/foundation.dart';
import 'package:qrypt/models/Qrypt.dart';

import '../models/compression_method.dart';
import '../models/encryption_method.dart';
import '../models/obfuscation_method.dart';
import '../models/sign_method.dart';
import 'crypto.dart';
import 'obfuscation/obfuscation_service.dart';

typedef TagMethods = ({
  CompressionMethod compression,
  EncryptionMethod encryption,
  SignMethod sign,
  ObfuscationMethod obfuscation,
});

/// Tag = first 6 hex chars of an HMAC over the method NAMES, then obfuscated
/// with the message's own obfuscation method (the tag is prepended to the
/// payload BEFORE obfuscation in InputHandler.handleProcess).
///
/// Invariants this class relies on (all covered in obfuscation_golden_test):
///  1. obfuscate(tag + payload).startsWith(obfuscate(tag)) for every method.
///     Holds for per-character/token codecs and rot13/xor. Holds for base64
///     ONLY because the tag is 6 bytes (a multiple of 3). Do not change the
///     tag length without rechecking. It would NOT hold for reverse.
///  2. No known tag is a prefix of another (see [findPrefixConflicts]).
///  3. Enum value names are frozen: they are hashed into the tag.
class TagManager {
  static Qrypt setTag(Qrypt q) {
    q.tag = tagHashFor(
      q.getCompressionMethod(),
      q.getEncryptionMethod(),
      q.getSignMethod(),
      q.getObfuscationMethod(),
    );
    return q;
  }

  /// Raw (un-obfuscated) tag hash for a combination.
  static String tagHashFor(
    CompressionMethod comp,
    EncryptionMethod enc,
    SignMethod sign,
    ObfuscationMethod obf,
  ) {
    final signPart = sign.name == 'none' ? '' : sign.name;
    return Crypto.generateTagHash('${comp.name}${enc.name}$signPart${obf.name}');
  }

  static final Map<String, TagMethods> _byTag = {};
  static List<String> _longestFirst = const [];

  /// Obfuscated tags currently recognised.
  static Iterable<String> get knownTags => _byTag.keys;

  /// Call AFTER ObfuscationService.rebuild(), and again after any map change.
  static void initializeTags() {
    _byTag.clear();
    for (final comp in CompressionMethod.values) {
      for (final enc in EncryptionMethod.values) {
        for (final sign in SignMethod.values) {
          for (final obf in ObfuscationMethod.values) {
            if (!ObfuscationService.isAvailable(obf)) continue;
            final tag = ObfuscationService.obfuscate(
              obf,
              tagHashFor(comp, enc, sign, obf),
            );
            final clash = _byTag[tag];
            if (clash != null) {
              // 24-bit hashes + a custom map can collide. Keep the first,
              // never guess silently.
              debugPrint(
                'TagManager: tag clash for "$tag": '
                '${clash.obfuscation.name} vs ${obf.name}; keeping first.',
              );
              continue;
            }
            _byTag[tag] = (
              compression: comp,
              encryption: enc,
              sign: sign,
              obfuscation: obf,
            );
          }
        }
      }
    }
    _longestFirst = _byTag.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (kDebugMode) {
      final conflicts = findPrefixConflicts();
      if (conflicts.isNotEmpty) {
        debugPrint('TagManager: ${conflicts.length} tag prefix conflicts');
      }
      debugPrint('Loaded ${_byTag.length} tag combinations');
    }
  }

  /// Kept for call-site compatibility.
  static void loadAllTags() => initializeTags();

  /// Pairs (shorter, longer) where one known tag is a proper prefix of
  /// another. Longest-first matching resolves them deterministically, but a
  /// message of the shorter kind whose payload begins like the longer tag's
  /// remainder would be misread. Should be empty; asserted in tests.
  static List<(String, String)> findPrefixConflicts() {
    final out = <(String, String)>[];
    for (final a in _byTag.keys) {
      for (final b in _byTag.keys) {
        if (a.length < b.length && b.startsWith(a)) out.add((a, b));
      }
    }
    return out;
  }

  /// True if [text] starts with a known obfuscated tag.
  static bool hasKnownTagPrefix(String text) => matchedTag(text) != null;

  /// The matched tag, longest match first.
  static String? matchedTag(String text) {
    for (final tag in _longestFirst) {
      if (text.startsWith(tag)) return tag;
    }
    return null;
  }

  /// O(1) for the exact tag returned by [matchedTag]; falls back to prefix
  /// matching to keep the old "tag may carry trailing text" behaviour.
  static TagMethods? getMethodsFromTag(String tag) {
    final exact = _byTag[tag];
    if (exact != null) return exact;
    final m = matchedTag(tag);
    return m == null ? null : _byTag[m];
  }
}
