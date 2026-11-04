import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/services/crypto.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.loadAllTags();
  });

  group('TagManager Collision & Bijection Invariants', () {
    test(
      'knownTags contains exactly 840 unique routing tags (zero collision)',
      () {
        final builtInObfs = ObfuscationMethod.values
            .where((m) => m != ObfuscationMethod.custom)
            .toList();
        final totalCombinations =
            CompressionMethod.values.length *
            EncryptionMethod.values.length *
            SignMethod.values.length *
            builtInObfs.length;

        expect(totalCombinations, equals(840));
        expect(
          TagManager.knownTags.length,
          equals(840),
          reason:
              'Collision detected in 6-character tag hashes! Multiple algorithm combinations mapped to the same tag.',
        );
      },
    );

    test(
      'every algorithm combination maps bijectively and decodes back to original methods',
      () {
        final seenTags = <String, String>{};
        final builtInObfs = ObfuscationMethod.values
            .where((m) => m != ObfuscationMethod.custom)
            .toList();

        for (final comp in CompressionMethod.values) {
          for (final enc in EncryptionMethod.values) {
            for (final sign in SignMethod.values) {
              for (final obf in builtInObfs) {
                final tagHash = TagManager.tagHashFor(comp, enc, sign, obf);
                final obfsTag = ObfuscationService.obfuscate(obf, tagHash);

                // Assert uniqueness across combinations
                final comboKey =
                    '${comp.name}_${enc.name}_${sign.name}_${obf.name}';
                if (seenTags.containsKey(obfsTag)) {
                  fail(
                    'Tag collision between "$comboKey" and "${seenTags[obfsTag]}": both produce "$obfsTag"',
                  );
                }
                seenTags[obfsTag] = comboKey;

                // Assert tag exists in loaded knownTags
                expect(
                  TagManager.knownTags.contains(obfsTag),
                  isTrue,
                  reason: 'knownTags missing tag "$obfsTag" for $comboKey',
                );

                // Assert bidirectional resolution
                final resolved = TagManager.getMethodsFromTag(obfsTag);
                expect(
                  resolved,
                  isNotNull,
                  reason:
                      'Failed to resolve methods from tag "$obfsTag" ($comboKey)',
                );
                expect(resolved!.compression, equals(comp));
                expect(resolved.encryption, equals(enc));
                expect(resolved.sign, equals(sign));
                expect(resolved.obfuscation, equals(obf));
              }
            }
          }
        }
      },
    );

    test('setTag populates Qrypt.tag matching expected hash', () {
      final q = Qrypt(
        text: 'hello',
        compression: CompressionMethod.gZip,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.en2,
        sign: SignMethod.none,
      );

      TagManager.setTag(q);
      final expectedHash = Crypto.generateTagHash('gZipaesGcmen2');
      expect(q.tag, equals(expectedHash));
    });

    test(
      'matchedTag correctly extracts prefix and rejects non-tag strings',
      () {
        final sampleTag = TagManager.knownTags.first;
        final payloadWithTag = '$sampleTag:some_encrypted_body_here';

        final matched = TagManager.matchedTag(payloadWithTag);
        expect(matched, equals(sampleTag));

        expect(TagManager.matchedTag('not_a_valid_tag_at_all'), isNull);
        expect(TagManager.matchedTag(''), isNull);
        expect(TagManager.matchedTag('123'), isNull);
      },
    );
  });
}
