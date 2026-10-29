import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/services/crypto.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Obfuscate.setAllMaps();
    TagManager.loadAllTags();
  });

  group('TagManager Collision & Bijection Invariants', () {
    test(
      'knownTags contains exactly 560 unique routing tags (zero collision)',
      () {
        final totalCombinations =
            CompressionMethod.values.length *
            EncryptionMethod.values.length *
            SignMethod.values.length *
            ObfuscationMethod.values.length;

        expect(totalCombinations, equals(560));
        expect(
          TagManager.knownTags.length,
          equals(560),
          reason:
              'Collision detected in 6-character tag hashes! Multiple algorithm combinations mapped to the same tag.',
        );
      },
    );

    test(
      'every algorithm combination maps bijectively and decodes back to original methods',
      () {
        final seenTags = <String, String>{};

        for (final comp in CompressionMethod.values) {
          for (final enc in EncryptionMethod.values) {
            for (final sign in SignMethod.values) {
              for (final obf in ObfuscationMethod.values) {
                final signPart = sign == SignMethod.none ? '' : sign.name;
                final rawTag = '${comp.name}${enc.name}$signPart${obf.name}';
                final tagHash = Crypto.generateTagHash(rawTag);

                final obfsTag = switch (obf) {
                  ObfuscationMethod.none => tagHash,
                  ObfuscationMethod.fa1 => Obfuscate.obfuscateText(
                    tagHash,
                    obfuscationFA1Map,
                  ),
                  ObfuscationMethod.fa2 => Obfuscate.obfuscateText(
                    tagHash,
                    obfuscationFA2Map,
                  ),
                  ObfuscationMethod.b64 => Obfuscate.obfuscateBase64(tagHash),
                  ObfuscationMethod.rot13 => Obfuscate.obfuscateROT13(tagHash),
                  ObfuscationMethod.xor => Obfuscate.obfuscateXOR(tagHash, 42),
                  ObfuscationMethod.en1 => Obfuscate.obfuscateText(
                    tagHash,
                    obfuscationEN1Map,
                  ),
                  ObfuscationMethod.en2 => Obfuscate.obfuscateText(
                    tagHash,
                    obfuscationEN2Map,
                  ),
                };

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
