import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/resources/obfuscation/v2_map_pools.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/obfuscation/v2_map_generator.dart';

void main() {
  final vectors =
      jsonDecode(File('test/fixtures/v2_generator_vectors.json').readAsStringSync())
          as Map<String, dynamic>;

  group('Sha256Random', () {
    test('matches the Python tool, value for value', () {
      final nv = vectors['nextInt'] as Map<String, dynamic>;
      final r = Sha256Random(nv['seed'] as String);
      for (final call in nv['calls'] as List) {
        final c = call as List;
        expect(r.nextInt(c[0] as int), c[1], reason: 'nextInt(${c[0]})');
      }
    });
  });

  group('pools', () {
    test('version matches the vectors (pools are frozen per version)', () {
      expect(kV2PoolsVersion, vectors['poolsVersion']);
    });

    test('no duplicates, all entries non-empty, enough to fill a map', () {
      for (final e in kV2CharPools.entries) {
        expect(e.value.toSet().length, e.value.length, reason: e.key);
        expect(e.value.every((s) => s.isNotEmpty), isTrue, reason: e.key);
        expect(
          e.value.length,
          greaterThanOrEqualTo(V2MapGenerator.symbols.length),
          reason: '${e.key} is too small for reliable generation',
        );
      }
      for (final e in kV2WordPools.entries) {
        expect(e.value.toSet().length, e.value.length, reason: e.key);
        expect(e.value.every((s) => s.isNotEmpty), isTrue, reason: e.key);
        expect(
          e.value.length,
          greaterThan(V2MapGenerator.symbols.length * 2),
          reason: '${e.key} is too small for reliable generation',
        );
      }
    });

    test('char pools hold exactly one code point per entry', () {
      for (final e in kV2CharPools.entries) {
        expect(e.value.every((s) => s.runes.length == 1), isTrue,
            reason: e.key);
      }
    });
  });

  group('generator', () {
    test('seeded output is identical to the Python tool for every pool', () {
      final maps = vectors['maps'] as Map<String, dynamic>;
      for (final pool in V2MapGenerator.allPools) {
        expect(
          V2MapGenerator.generate(
            pool,
            random: Sha256Random(vectors['seed'] as String),
          ),
          Map<String, String>.from(maps[pool] as Map),
          reason: 'pool $pool',
        );
      }
    });

    test('200 random maps per pool are valid, complete and distinct', () {
      final rnd = Random(7);
      for (final pool in V2MapGenerator.allPools) {
        final seen = <String>{};
        for (var i = 0; i < 200; i++) {
          final m = V2MapGenerator.generate(pool, random: rnd);
          expect(ObfuscationService.validateV2Map(m), isEmpty, reason: pool);
          expect(m.keys.toSet(), V2MapGenerator.symbols.toSet());
          expect(m.values.toSet().length, 17, reason: pool);
          seen.add(m.values.join('|'));
        }
        expect(seen.length, greaterThan(190), reason: '$pool is not random');
      }
    });

    test('generated maps round-trip through the real codec', () {
      const payload = 'deadbeef:0123456789abcdef';
      for (final pool in V2MapGenerator.allPools) {
        final m = V2MapGenerator.generate(pool, random: Random(1));
        ObfuscationService.rebuildWith({ObfuscationMethod.en1v2: m});
        expect(ObfuscationService.isAvailable(ObfuscationMethod.en1v2), isTrue,
            reason: '$pool: ${ObfuscationService.unavailableReason(ObfuscationMethod.en1v2)}');
        final enc = ObfuscationService.obfuscate(ObfuscationMethod.en1v2, payload);
        expect(
          ObfuscationService.deobfuscate(ObfuscationMethod.en1v2, enc),
          payload,
          reason: pool,
        );
      }
    });

    test('passphrase is reproducible; different phrase differs', () {
      final a = V2MapGenerator.fromPassphrase('fa-words', 'blue door');
      expect(V2MapGenerator.fromPassphrase('fa-words', 'blue door'), a);
      expect(V2MapGenerator.fromPassphrase('fa-words', 'red door'), isNot(a));
    });

    test('unknown pool is rejected', () {
      expect(() => V2MapGenerator.generate('klingon'), throwsArgumentError);
    });
  });

  group('validateV2Map rejects what the legacy maps got wrong', () {
    Map<String, String> base(String pool) =>
        V2MapGenerator.generate(pool, random: Sha256Random('base'));

    bool mentions(Map<String, String> m, String text) =>
        ObfuscationService.validateV2Map(m).any((p) => p.contains(text));

    test('combining mark (legacy FA1 5/6/c/d/f)', () {
      final m = base('persian')..['c'] = '\u06E7';
      expect(mentions(m, 'U+06E7'), isTrue);
    });

    test('character outside the vetted pools', () {
      final m = base('latin')..['a'] = '\u00E9';
      expect(mentions(m, 'U+00E9'), isTrue);
    });

    test('uppercase value', () {
      final m = base('latin')..['a'] = 'A';
      expect(mentions(m, 'lowercase'), isTrue);
    });

    test('prefix clash (legacy FA2 چه / چهار)', () {
      final m = base('en-words')
        ..['0'] = 'fir'
        ..['1'] = 'first';
      expect(mentions(m, 'prefix-free'), isTrue);
    });

    test('collision (legacy FA1 Q and 9 both map to ز)', () {
      final m = base('latin');
      m['b'] = m['a']!;
      expect(ObfuscationService.validateV2Map(m), isNotEmpty);
    });

    test('missing separator and extra key', () {
      final m = base('latin')..remove(':');
      expect(ObfuscationService.validateV2Map(m), isNotEmpty);
      final n = base('latin')..['g'] = 'z';
      expect(mentions(n, 'Unexpected key'), isTrue);
    });
  });
}
