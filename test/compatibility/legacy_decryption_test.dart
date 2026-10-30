import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/resources/obfuscation/built_in_obfuscation_maps.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final Map<String, dynamic> vectorSuite;
  late final String testKey;
  late final List<dynamic> vectors;
  late final InputHandler inputHandler;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    // Initialize required subsystems
    await Obfuscate.setAllMaps();
    Compression.setNativeLibPaths();
    TagManager.loadAllTags();

    inputHandler = InputHandler();

    final vectorFile = File(
      'test/compatibility/golden_vectors/v4_vectors.json',
    );
    expect(
      vectorFile.existsSync(),
      isTrue,
      reason:
          'Golden vectors file must exist under test/compatibility/golden_vectors/',
    );

    final rawJson = vectorFile.readAsStringSync();
    vectorSuite = jsonDecode(rawJson) as Map<String, dynamic>;
    testKey = vectorSuite['test_key'] as String;
    vectors = vectorSuite['vectors'] as List<dynamic>;

    expect(vectors, isNotEmpty);
  });

  group('Golden Vector Decrypt-Only Compatibility', () {
    test(
      'all historical golden vectors decrypt deterministically to expected plaintexts',
      () async {
        for (final rawVec in vectors) {
          final vec = rawVec as Map<String, dynamic>;
          final id = vec['id'] as String;
          final ciphertext = vec['ciphertext'] as String;
          final expectedPlaintext = vec['plaintext'] as String;
          final useTag = vec['use_tag'] as bool;
          final originVersion = vec['origin_version'] as String;

          late final Qrypt qrypt;
          if (useTag) {
            qrypt = Qrypt.autoDecrypt(text: ciphertext);
            qrypt.useCustomKey = true;
            qrypt.customKey = testKey;
          } else {
            qrypt = Qrypt.withTag(
              text: ciphertext,
              compression: CompressionMethod.values.firstWhere(
                (c) => c.name == vec['compression'],
              ),
              encryption: EncryptionMethod.values.firstWhere(
                (e) => e.name == vec['encryption'],
              ),
              obfuscation: ObfuscationMethod.values.firstWhere(
                (o) => o.name == vec['obfuscation'],
              ),
              sign: SignMethod.none,
              useTag: false,
            );
            qrypt.useCustomKey = true;
            qrypt.customKey = testKey;
          }

          final result = await inputHandler.handleDeProcess(
            null,
            qrypt,
            useTag,
          );

          expect(
            result.text,
            equals(expectedPlaintext),
            reason:
                'Vector $id (origin $originVersion) failed to decrypt to expected plaintext',
          );
        }
      },
    );

    test(
      'default preset vector (GZip + AES-GCM + EN2) preserves Persian Unicode plaintext',
      () async {
        final persianVec =
            vectors.firstWhere((v) => v['id'] == 'v4_default_preset_persian')
                as Map<String, dynamic>;

        final q = Qrypt.autoDecrypt(text: persianVec['ciphertext'] as String);
        q.useCustomKey = true;
        q.customKey = testKey;

        final result = await inputHandler.handleDeProcess(null, q, true);
        expect(
          result.text,
          equals('پیام محرمانه برای تست سازگاری Qrypt - فارسی 1234'),
        );
        expect(q.compression, equals(CompressionMethod.gZip));
        expect(q.encryption, equals(EncryptionMethod.aesGcm));
        expect(q.obfuscation, equals(ObfuscationMethod.en2));
      },
    );

    test(
      'colons and delimiter vector preserves internal colon structure',
      () async {
        final colonVec =
            vectors.firstWhere((v) => v['id'] == 'v4_colons_and_delimiters')
                as Map<String, dynamic>;

        final q = Qrypt.autoDecrypt(text: colonVec['ciphertext'] as String);
        q.useCustomKey = true;
        q.customKey = testKey;

        final result = await inputHandler.handleDeProcess(null, q, true);
        expect(result.text, equals(colonVec['plaintext']));
        expect(result.text.contains(':'), isTrue);
      },
    );

    test(
      'large payload vector (4KB+) decompresses without framing truncation',
      () async {
        final largeVec =
            vectors.firstWhere((v) => v['id'] == 'v4_large_payload_framing')
                as Map<String, dynamic>;

        final q = Qrypt.autoDecrypt(text: largeVec['ciphertext'] as String);
        q.useCustomKey = true;
        q.customKey = testKey;

        final result = await inputHandler.handleDeProcess(null, q, true);
        expect(result.text, equals(largeVec['plaintext']));
        expect(result.text.length, greaterThan(3000));
      },
    );

    test(
      'empty string vector decrypts cleanly without range or padding error',
      () async {
        final emptyVec =
            vectors.firstWhere((v) => v['id'] == 'v4_empty_string')
                as Map<String, dynamic>;

        final q = Qrypt.autoDecrypt(text: emptyVec['ciphertext'] as String);
        q.useCustomKey = true;
        q.customKey = testKey;

        final result = await inputHandler.handleDeProcess(null, q, true);
        expect(result.text, equals(''));
      },
    );
  });

  group('Untagged Legacy Payload Fallback', () {
    test(
      'untagged ciphertext fails auto-detection and succeeds with explicit manual parameters',
      () async {
        final manualVec =
            vectors.firstWhere(
                  (v) => v['id'] == 'v4_untagged_manual_gzip_gcm_en1',
                )
                as Map<String, dynamic>;

        final rawCiphertext = manualVec['ciphertext'] as String;

        // 1. Tag detection must fail on untagged ciphertext
        final matchedTag = TagManager.matchedTag(rawCiphertext);
        expect(
          matchedTag,
          isNull,
          reason: 'Untagged ciphertext should not match any routing tag',
        );

        // 2. Calling auto-decrypt handleDeProcess must throw FormatException
        final autoQrypt = Qrypt.autoDecrypt(text: rawCiphertext);
        expect(
          () => inputHandler.handleDeProcess(null, autoQrypt, true),
          throwsA(isA<FormatException>()),
        );

        // 3. Explicit manual parameters must succeed
        final manualQrypt = Qrypt.withTag(
          text: rawCiphertext,
          compression: CompressionMethod.values.firstWhere(
            (c) => c.name == manualVec['compression'],
          ),
          encryption: EncryptionMethod.values.firstWhere(
            (e) => e.name == manualVec['encryption'],
          ),
          obfuscation: ObfuscationMethod.values.firstWhere(
            (o) => o.name == manualVec['obfuscation'],
          ),
          sign: SignMethod.none,
          useTag: false,
        );
        manualQrypt.useCustomKey = true;
        manualQrypt.customKey = testKey;

        final result = await inputHandler.handleDeProcess(
          null,
          manualQrypt,
          false,
        );
        expect(result.text, equals(manualVec['plaintext']));
      },
    );
  });

  group('Negative and Security Invariants', () {
    test(
      'wrong AES-GCM key fails with authentication failure, never returns garbage',
      () async {
        final gcmVec =
            vectors.firstWhere((v) => v['id'] == 'v4_default_preset_persian')
                as Map<String, dynamic>;

        final q = Qrypt.autoDecrypt(text: gcmVec['ciphertext'] as String);
        q.useCustomKey = true;
        // Wrong 32-byte key
        q.customKey = 'wrong_32_byte_key_00000000000000';

        expect(
          () => inputHandler.handleDeProcess(null, q, true),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('tampered ciphertext in AES-GCM throws authentication error', () async {
      final gcmVec =
          vectors.firstWhere((v) => v['id'] == 'v4_default_preset_persian')
              as Map<String, dynamic>;

      final originalCiphertext = gcmVec['ciphertext'] as String;
      // Tamper with the payload body (flip a character in the ciphertext portion)
      final tamperedCiphertext = originalCiphertext.replaceRange(
        originalCiphertext.length - 5,
        originalCiphertext.length - 4,
        originalCiphertext[originalCiphertext.length - 5] == 'a' ? 'b' : 'a',
      );

      final q = Qrypt.autoDecrypt(text: tamperedCiphertext);
      q.useCustomKey = true;
      q.customKey = testKey;

      expect(
        () => inputHandler.handleDeProcess(null, q, true),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'tampered tag prefix throws FormatException without executing crypto pipeline',
      () async {
        final gcmVec =
            vectors.firstWhere((v) => v['id'] == 'v4_default_preset_persian')
                as Map<String, dynamic>;

        // Replace tag prefix with invalid garbage
        final tamperedWithBogusTag =
            'INVALID_TAG_PREFIX_' + (gcmVec['ciphertext'] as String);

        final q = Qrypt.autoDecrypt(text: tamperedWithBogusTag);
        q.useCustomKey = true;
        q.customKey = testKey;

        expect(
          () => inputHandler.handleDeProcess(null, q, true),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid tag format'),
            ),
          ),
        );
      },
    );

    test('unknown tag returns null in TagManager.matchedTag', () {
      expect(TagManager.matchedTag('xyz999boguspayload'), isNull);
      expect(TagManager.matchedTag(''), isNull);
      expect(TagManager.matchedTag('12345'), isNull);
    });
  });

  group('Obfuscation Map Snapshot Invariants', () {
    String hashCanonicalMap(Map<String, String> map) {
      final sortedKeys = map.keys.toList()..sort();
      final canonical = sortedKeys.map((k) => '$k:${map[k]}').join('|');
      return sha256.convert(utf8.encode(canonical)).toString();
    }

    test('builtInEn1Map matches frozen SHA-256 snapshot', () {
      const expectedHash =
          'a048ced9ada6f0c392037a552ed8482f7ea9fdf51929b28a24fd440a0949b4df';
      expect(hashCanonicalMap(builtInEn1Map), equals(expectedHash));
    });

    test('builtInEn2Map matches frozen SHA-256 snapshot', () {
      const expectedHash =
          'd9723cbab34e91347f91d8988a3a0914bdd7382d45829405b58351281acf62d7';
      expect(hashCanonicalMap(builtInEn2Map), equals(expectedHash));
    });

    test('builtInFa1Map matches frozen SHA-256 snapshot', () {
      const expectedHash =
          'eb89c47dc4606819781000c129b08ac80ef3b04aa98764ad1c4d5bad2397dc59';
      expect(hashCanonicalMap(builtInFa1Map), equals(expectedHash));
    });

    test('builtInFa2Map matches frozen SHA-256 snapshot', () {
      const expectedHash =
          'a7b9c7b712da6bf5df3ba8aa48efcd7e87d23eada581939b361aa1a7312ac425';
      expect(hashCanonicalMap(builtInFa2Map), equals(expectedHash));
    });
  });

  group('v4 to v5 Migration Bridge Invariant', () {
    test(
      'ciphertext encrypted with custom key fails with default key and succeeds when custom key is supplied',
      () async {
        final gcmVec =
            vectors.firstWhere((v) => v['id'] == 'v4_default_preset_persian')
                as Map<String, dynamic>;

        // 1. Decryption attempt without custom key (relying on default key or prompting) fails
        final qWithoutKey = Qrypt.autoDecrypt(
          text: gcmVec['ciphertext'] as String,
        );
        qWithoutKey.useCustomKey = false;

        expect(
          () => inputHandler.handleDeProcess(null, qWithoutKey, true),
          throwsA(isA<Exception>()),
        );

        // 2. Decryption attempt with custom key supplied succeeds
        final qWithKey = Qrypt.autoDecrypt(
          text: gcmVec['ciphertext'] as String,
        );
        qWithKey.useCustomKey = true;
        qWithKey.customKey = testKey;

        final successResult = await inputHandler.handleDeProcess(
          null,
          qWithKey,
          true,
        );
        expect(successResult.text, equals(gcmVec['plaintext']));
      },
    );
  });
}
