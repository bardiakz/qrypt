import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:qrypt/resources/obfuscation/v2_map_pools.dart';

import 'obfuscation_service.dart';

/// Creates random v2 maps (16 hex digits + ':') from the vetted pools in
/// v2_map_pools.dart. Intended for a future "create my own map" feature.
///
/// The algorithm is identical to `tool/v2_maps.py` (shuffle the pool,
/// take candidates in order, skip any that break a rule), so a seeded map
/// can be reproduced by the script, and test/fixtures/v2_generator_vectors.json
/// proves both agree.
///
/// Every result is passed through [ObfuscationService.validateV2Map] before
/// it is returned, so a bad map can never leave this class.
///
/// IMPORTANT for the UI that uses this: the message TAG only records the
/// obfuscation METHOD (e.g. en2v2), not WHICH map. A recipient needs the same
/// map, so offer export/import, and warn that editing or replacing a map makes
/// older messages undecodable. (Consider putting a short map fingerprint into
/// messages made with custom maps.)
class V2MapGenerator {
  V2MapGenerator._();

  /// Order is the assignment order: the i-th chosen value maps to symbols[i].
  static const List<String> symbols = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', //
    'a', 'b', 'c', 'd', 'e', 'f', ':',
  ];

  /// One character per symbol.
  static List<String> get charPools => kV2CharPools.keys.toList();

  /// One word per symbol (longer output, readable as text).
  static List<String> get wordPools => kV2WordPools.keys.toList();

  static List<String> get allPools => [...charPools, ...wordPools];

  static bool isWordPool(String pool) => kV2WordPools.containsKey(pool);

  /// A fresh random map. Uses a cryptographically secure source by default.
  static Map<String, String> generate(String pool, {Random? random}) {
    final isWord = isWordPool(pool);
    final items = isWord ? kV2WordPools[pool] : kV2CharPools[pool];
    if (items == null) {
      throw ArgumentError.value(
        pool,
        'pool',
        'Unknown pool. Known: ${allPools.join(', ')}',
      );
    }

    final rnd = random ?? Random.secure();
    final chosen = <String>[];
    for (final cand in _shuffled(items, rnd)) {
      final pos = chosen.length;
      if (isWord) {
        // Keep the word set prefix-free (see ObfuscationService.validateV2Map).
        if (chosen.any((c) => cand.startsWith(c) || c.startsWith(cand))) {
          continue;
        }
      } else if (cand == symbols[pos]) {
        continue; // no symbol maps to itself
      }
      chosen.add(cand);
      if (chosen.length == symbols.length) break;
    }
    if (chosen.length < symbols.length) {
      throw StateError('Pool "$pool" cannot supply ${symbols.length} entries.');
    }

    final map = {
      for (var i = 0; i < symbols.length; i++) symbols[i]: chosen[i],
    };
    final problems = ObfuscationService.validateV2Map(map);
    if (problems.isNotEmpty) {
      throw StateError('Generated map failed validation:\n${problems.join('\n')}');
    }
    return map;
  }

  /// Same passphrase + same pool (and [kV2PoolsVersion]) => same map.
  /// Handy for "type a phrase on both phones". The passphrase is NOT a secret
  /// protecting the data (obfuscation is not encryption); it only recreates the
  /// map, and weak phrases are guessable.
  static Map<String, String> fromPassphrase(String pool, String passphrase) =>
      generate(pool, random: Sha256Random(passphrase));

  /// Fisher-Yates from the end, exactly like the Python tool.
  static List<String> _shuffled(List<String> pool, Random rnd) {
    final a = List<String>.of(pool);
    for (var i = a.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final t = a[i];
      a[i] = a[j];
      a[j] = t;
    }
    return a;
  }
}

/// Deterministic [Random] whose stream is SHA-256("$seed:$counter"), consumed
/// as 4-byte big-endian words with rejection sampling. Bit-for-bit the same as
/// `_stream` / `_randbelow` in tool/v2_maps.py. Not for security purposes.
class Sha256Random implements Random {
  Sha256Random(this.seed);

  final String seed;
  int _counter = 0;
  final List<int> _words = [];
  int _pos = 0;

  int _nextWord() {
    if (_pos >= _words.length) {
      final d = sha256.convert(utf8.encode('$seed:${_counter++}')).bytes;
      _words.clear();
      _pos = 0;
      for (var i = 0; i < 32; i += 4) {
        // Arithmetic, not shifts, so it is also correct on the web.
        _words.add(d[i] * 16777216 + d[i + 1] * 65536 + d[i + 2] * 256 + d[i + 3]);
      }
    }
    return _words[_pos++];
  }

  @override
  int nextInt(int max) {
    if (max < 1 || max > 0x100000000) {
      throw RangeError.range(max, 1, 0x100000000, 'max');
    }
    final limit = 0x100000000 - (0x100000000 % max);
    while (true) {
      final v = _nextWord();
      if (v < limit) return v % max;
    }
  }

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(1 << 30) / (1 << 30);
}
