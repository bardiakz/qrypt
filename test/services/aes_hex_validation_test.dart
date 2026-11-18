import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/services/aes_encryption.dart';

void main() {
  group('Aes.fromHex and Decryption Validation Tests', () {
    test('parses valid even-length hex strings correctly', () {
      final bytes = Aes.fromHex('000102030405060708090a0b0c0d0e0f');
      expect(bytes.length, equals(16));
      expect(bytes, equals(Uint8List.fromList(List.generate(16, (i) => i))));

      final upperBytes = Aes.fromHex('A1B2C3D4');
      expect(upperBytes, equals(Uint8List.fromList([0xa1, 0xb2, 0xc3, 0xd4])));

      final empty = Aes.fromHex('');
      expect(empty, equals(Uint8List(0)));
    });

    test('rejects odd-length hex strings with FormatException', () {
      expect(
        () => Aes.fromHex('a'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Hex string must have an even length'),
          ),
        ),
      );

      expect(
        () => Aes.fromHex('123'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('got length 3'),
          ),
        ),
      );

      expect(
        () => Aes.fromHex('010203040'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('got length 9'),
          ),
        ),
      );
    });

    test('rejects non-hex characters with FormatException', () {
      expect(() => Aes.fromHex('zz'), throwsA(isA<FormatException>()));
      expect(() => Aes.fromHex('010g'), throwsA(isA<FormatException>()));
    });

    test('decryptAesCbc throws FormatException on odd-length ciphertext or IV', () {
      final key = encrypt.Key.fromUtf8('12345678901234567890123456789012');
      const validIv = '000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f';

      // Odd ciphertext
      expect(
        () => Aes.decryptAesCbc('abc', validIv, key),
        throwsA(isA<FormatException>()),
      );

      // Odd IV
      expect(
        () => Aes.decryptAesCbc('abcd', '012', key),
        throwsA(isA<FormatException>()),
      );
    });

    test('decryptAesCtr throws FormatException on odd-length ciphertext or IV', () {
      final key = encrypt.Key.fromUtf8('12345678901234567890123456789012');
      const validIv = '000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f';

      // Odd ciphertext
      expect(
        () => Aes.decryptAesCtr('abc', validIv, key),
        throwsA(isA<FormatException>()),
      );

      // Odd IV
      expect(
        () => Aes.decryptAesCtr('abcd', '012', key),
        throwsA(isA<FormatException>()),
      );
    });

    test('decryptAesGcm gracefully returns null on odd-length inputs', () {
      final key = encrypt.Key.fromUtf8('12345678901234567890123456789012');
      const validIv = '000102030405060708090a0b';

      expect(Aes.decryptAesGcm('abc', validIv, key), isNull);
      expect(Aes.decryptAesGcm('abcd', '123', key), isNull);
    });
  });
}
