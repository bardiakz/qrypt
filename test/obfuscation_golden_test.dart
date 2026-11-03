import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obfuscate/obfuscate.dart' as obfs;
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/resources/obfuscation/built_in_obfuscation_maps.dart';
import 'package:qrypt/resources/obfuscation/built_in_v2_maps.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/tag_manager.dart';

import 'golden/golden_inputs.dart';

void main() {
  late Map<String, dynamic> golden;

  setUpAll(() {
    golden =
        jsonDecode(File('test/fixtures/obfuscation_golden.json').readAsStringSync())
            as Map<String, dynamic>;
    ObfuscationService.rebuildWith({
      ObfuscationMethod.en1: builtInEn1Map,
      ObfuscationMethod.en2: builtInEn2Map,
      ObfuscationMethod.fa1: builtInFa1Map,
      ObfuscationMethod.fa2: builtInFa2Map,
      for (final m in ObfuscationMethod.values)
        if (m.isV2Mapped) m: builtInV2MapForMethod(m),
    });
    TagManager.initializeTags();
  });

  const legacy = {
    'en1': ObfuscationMethod.en1,
    'en2': ObfuscationMethod.en2,
    'fa1': ObfuscationMethod.fa1,
    'fa2': ObfuscationMethod.fa2,
    'b64': ObfuscationMethod.b64,
    'rot13': ObfuscationMethod.rot13,
  };

  group('legacy compatibility (fixtures from the OLD package)', () {
    legacy.forEach((name, method) {
      test('$name: encode and decode are byte-identical', () {
        final inputs = goldenInputs();
        final g = golden['outputs'][name] as Map<String, dynamic>;
        for (var i = 0; i < inputs.length; i++) {
          final enc = (g['encoded'] as List)[i] as String;
          expect(
            ObfuscationService.obfuscate(method, inputs[i]),
            enc,
            reason: '$name encode, input #$i',
          );
          expect(
            ObfuscationService.deobfuscate(method, enc),
            (g['roundTrip'] as List)[i],
            reason: '$name decode, input #$i',
          );
        }
      });
    });

    test('every tag the old app recognised still resolves identically', () {
      final tags = golden['tags'] as Map<String, dynamic>;
      expect(tags, isNotEmpty);
      tags.forEach((tag, names) {
        // Legacy XOR support was intentionally dropped.
        if (names['obfuscation'] == 'xor') return;
        final got = TagManager.getMethodsFromTag(tag);
        expect(got, isNotNull, reason: 'lost tag $tag');
        expect(got!.compression.name, names['compression']);
        expect(got.encryption.name, names['encryption']);
        expect(got.sign.name, names['sign']);
        expect(got.obfuscation.name, names['obfuscation']);
        expect(TagManager.matchedTag(tag), tag);
      });
    });
  });

  group('v2 formats', () {
    final v2 = ObfuscationMethod.values.where((m) => m.isV2Mapped);

    for (final m in v2) {
      // If this fails, `reason` says exactly which map entries to fix.
      test('${m.name}: built-in map is valid for hex + separator payloads', () {
        expect(
          ObfuscationService.isAvailable(m),
          isTrue,
          reason: ObfuscationService.unavailableReason(m),
        );
      });

      test('${m.name}: round-trips every hex/AES-style golden input', () {
        if (!ObfuscationService.isAvailable(m)) return;
        for (final s in goldenInputs().where(
          (s) => RegExp(r'^[0-9a-f:]*$').hasMatch(s),
        )) {
          expect(
            ObfuscationService.deobfuscate(
              m,
              ObfuscationService.obfuscate(m, s),
            ),
            s,
          );
        }
      });

      test('${m.name}: rejects garbage instead of returning wrong data', () {
        if (!ObfuscationService.isAvailable(m)) return;
        expect(
          () => ObfuscationService.deobfuscate(m, 'not-a-valid-payload!'),
          throwsA(isA<obfs.ObfuscationException>()),
        );
      });
    }
  });

  group('v2 maps are frozen', () {
    // The lock file is written once by tool/v2_maps.py. A v2 map is a wire
    // format: changing an entry makes every existing message undecodable.
    test('built-in v2 maps equal test/fixtures/v2_maps.lock.json', () {
      final lock =
          (jsonDecode(File('test/fixtures/v2_maps.lock.json').readAsStringSync())
                  as Map<String, dynamic>)['maps']
              as Map<String, dynamic>;
      for (final m in ObfuscationMethod.values.where((m) => m.isV2Mapped)) {
        expect(
          builtInV2MapForMethod(m),
          Map<String, String>.from(lock[m.name] as Map),
          reason: '${m.name} changed. This breaks existing messages.',
        );
      }
    });
  });

  group('tag invariants', () {
    // Mirrors InputHandler exactly: tag + payload is obfuscated together,
    // the tag is stripped by LENGTH of the separately-obfuscated tag, and the
    // remainder is deobfuscated on its own.
    for (final m in ObfuscationMethod.values) {
      test('${m.name}: prefix property and remainder decode', () {
        if (!ObfuscationService.isAvailable(m)) return;
        final tag = TagManager.tagHashFor(
          CompressionMethod.values.first,
          EncryptionMethod.values.first,
          SignMethod.values.first,
          m,
        );
        final payload = m.isHexMapped
            ? 'deadbeef:0123456789abcdef' // AES layout: ciphertext:iv
            : 'SGVsbG8gV29ybGQ+/w==';
        final prefix = ObfuscationService.obfuscate(m, tag);
        final full = ObfuscationService.obfuscate(m, tag + payload);
        expect(full.startsWith(prefix), isTrue, reason: 'prefix property');
        final decoded = ObfuscationService.deobfuscate(
          m,
          full.substring(prefix.length),
        );
        if (m.isLegacyMapped && m.isHexMapped) {
          // Legacy map codecs deobfuscate to uppercase; AES hex is case-insensitive.
          expect(decoded.toLowerCase(), payload.toLowerCase());
        } else {
          expect(decoded, payload);
        }
      });
    }

    test('no known tag is a prefix of another', () {
      expect(TagManager.findPrefixConflicts(), isEmpty);
    });
  });
}
