import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/resources/global_resources.dart';
import 'package:qrypt/services/aes_encryption.dart';

void main() {
  group('generateRandomAesKey (Full-Entropy 128/192/256-bit)', () {
    test('generates true 256-bit key (44-char Base64 -> 32 raw bytes) by default', () {
      final key = generateRandomAesKey();
      expect(key.length, equals(44));
      expect(key.endsWith('='), isTrue);
      expect(validateAesKey(key), isNull);

      final parsed = parseAesKey(key);
      expect(parsed.bytes.length, equals(32));
      expect(parsed.bytes, equals(base64.decode(key)));

      final model = AESKey(
        id: 'k256',
        name: '256',
        key: key,
        createdAt: DateTime.now(),
      );
      expect(model.byteLength, equals(32));
      expect(model.bitLength, equals(256));
    });

    test('generates true 128-bit key (24-char Base64 -> 16 raw bytes)', () {
      final key16 = generateRandomAesKey(length: 16);
      expect(key16.length, equals(24));
      expect(key16.endsWith('=='), isTrue);
      expect(validateAesKey(key16), isNull);

      final parsed = parseAesKey(key16);
      expect(parsed.bytes.length, equals(16));
      expect(parsed.bytes, equals(base64.decode(key16)));

      final model = AESKey(
        id: 'k128',
        name: '128',
        key: key16,
        createdAt: DateTime.now(),
      );
      expect(model.byteLength, equals(16));
      expect(model.bitLength, equals(128));
    });

    test('generates true 192-bit key (48-char Hex -> 24 raw bytes)', () {
      final key24 = generateRandomAesKey(length: 24);
      expect(key24.length, equals(48));
      expect(RegExp(r'^[0-9a-f]{48}$').hasMatch(key24), isTrue);
      expect(validateAesKey(key24), isNull);

      final parsed = parseAesKey(key24);
      expect(parsed.bytes.length, equals(24));

      final model = AESKey(
        id: 'k192',
        name: '192',
        key: key24,
        createdAt: DateTime.now(),
      );
      expect(model.byteLength, equals(24));
      expect(model.bitLength, equals(192));
    });

    test('rejects unsupported byte lengths', () {
      expect(() => generateRandomAesKey(length: 8), throwsArgumentError);
      expect(() => generateRandomAesKey(length: 20), throwsArgumentError);
      expect(() => generateRandomAesKey(length: 64), throwsArgumentError);
    });

    test('AES-GCM round-trips with newly generated 128, 192, and 256-bit keys', () {
      final plaintext = Uint8List.fromList(utf8.encode('Full entropy AES test'));

      for (final byteLen in [16, 24, 32]) {
        final keyStr = generateRandomAesKey(length: byteLen);
        final key = parseAesKey(keyStr);
        expect(key.bytes.length, equals(byteLen));

        final enc = Aes.encryptAesGcm(plaintext, key);
        final dec = Aes.decryptAesGcm(enc['ciphertext']!, enc['iv']!, key);
        expect(dec, equals(plaintext));
      }
    });

    test('preserves legacy 16, 24, and 32-byte UTF-8 keys without collision', () {
      const legacy128 = '1234567890123456';
      const legacy192 = '123456789012345678901234';
      const legacy256HexLooking = '0123456789abcdef0123456789abcdef';

      expect(validateAesKey(legacy128), isNull);
      expect(validateAesKey(legacy192), isNull);
      expect(validateAesKey(legacy256HexLooking), isNull);

      expect(parseAesKey(legacy128).bytes, equals(utf8.encode(legacy128)));
      expect(parseAesKey(legacy192).bytes, equals(utf8.encode(legacy192)));
      expect(
        parseAesKey(legacy256HexLooking).bytes,
        equals(utf8.encode(legacy256HexLooking)),
      );
    });

    test('generates 500 distinct keys with full byte range coverage', () {
      final generatedKeys = <String>{};
      final seenByteValues = <int>{};
      const samples = 500;

      for (var i = 0; i < samples; i++) {
        final key = generateRandomAesKey();
        generatedKeys.add(key);
        seenByteValues.addAll(parseAesKey(key).bytes);
      }

      expect(generatedKeys.length, equals(samples));
      // Across 500 * 32 = 16,000 random bytes, virtually all 256 byte values appear
      // (proving full 8-bit/byte entropy instead of 64-symbol ASCII range)
      expect(seenByteValues.length, equals(256));
    });
  });
}
