import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/services/aes_encryption.dart';

void main() {
  group('AES Random IV & Nonce Regression Tests', () {
    final key = encrypt.Key.fromUtf8('12345678901234567890123456789012');
    final plaintext = Uint8List.fromList(
      utf8.encode('TopSecretConfidentialMessagePayload123456'),
    );

    test(
      'AES-CBC generates distinct IVs and ciphertexts for identical plaintext and key',
      () {
        final enc1 = Aes.encryptAesCbc(plaintext, key);
        final enc2 = Aes.encryptAesCbc(plaintext, key);

        expect(enc1['iv'], isNotEmpty);
        expect(enc2['iv'], isNotEmpty);

        // Invariant: Nonces must not be reused across encryptions
        expect(enc1['iv'], isNot(equals(enc2['iv'])));
        expect(enc1['ciphertext'], isNot(equals(enc2['ciphertext'])));

        // Invariant: Nonce must not be all-zero (regression test against IV.fromLength(16))
        expect(enc1['iv'], isNot(equals('00000000000000000000000000000000')));
        expect(enc2['iv'], isNot(equals('00000000000000000000000000000000')));

        // Invariant: Both decrypt to original plaintext
        final dec1 = Aes.decryptAesCbc(enc1['ciphertext']!, enc1['iv']!, key);
        final dec2 = Aes.decryptAesCbc(enc2['ciphertext']!, enc2['iv']!, key);
        expect(dec1, equals(plaintext));
        expect(dec2, equals(plaintext));
      },
    );

    test(
      'AES-CTR generates distinct IVs and ciphertexts for identical plaintext and key',
      () {
        final enc1 = Aes.encryptAesCtr(plaintext, key);
        final enc2 = Aes.encryptAesCtr(plaintext, key);

        expect(enc1['iv'], isNotEmpty);
        expect(enc2['iv'], isNotEmpty);

        // Invariant: Keystream reuse vulnerability eliminated (IVs and ciphertexts must differ)
        expect(enc1['iv'], isNot(equals(enc2['iv'])));
        expect(enc1['ciphertext'], isNot(equals(enc2['ciphertext'])));

        // Invariant: Nonce must not be all-zero (regression test against IV.fromLength(16))
        expect(enc1['iv'], isNot(equals('00000000000000000000000000000000')));
        expect(enc2['iv'], isNot(equals('00000000000000000000000000000000')));

        // Invariant: Both decrypt to original plaintext
        final dec1 = Aes.decryptAesCtr(enc1['ciphertext']!, enc1['iv']!, key);
        final dec2 = Aes.decryptAesCtr(enc2['ciphertext']!, enc2['iv']!, key);
        expect(dec1, equals(plaintext));
        expect(dec2, equals(plaintext));
      },
    );

    test(
      'AES-GCM generates distinct 12-byte random nonces and ciphertexts',
      () {
        final enc1 = Aes.encryptAesGcm(plaintext, key);
        final enc2 = Aes.encryptAesGcm(plaintext, key);

        expect(enc1['iv'], isNotEmpty);
        expect(enc2['iv'], isNotEmpty);

        // GCM IV length is 12 bytes = 24 hex characters
        expect(enc1['iv']!.length, equals(24));
        expect(enc2['iv']!.length, equals(24));

        // Nonces and ciphertexts must differ
        expect(enc1['iv'], isNot(equals(enc2['iv'])));
        expect(enc1['ciphertext'], isNot(equals(enc2['ciphertext'])));

        // Both decrypt to original plaintext
        final dec1 = Aes.decryptAesGcm(enc1['ciphertext']!, enc1['iv']!, key);
        final dec2 = Aes.decryptAesGcm(enc2['ciphertext']!, enc2['iv']!, key);
        expect(dec1, equals(plaintext));
        expect(dec2, equals(plaintext));
      },
    );
  });
}
