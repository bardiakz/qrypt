import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/rsa/rsa_key_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RSAKeyService rsaService;
  late RSAKeyPair generatedKeyPair;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    rsaService = RSAKeyService(storageService: RSAKeyStorageService());

    // Generate one 2048-bit key pair for reuse across tests
    generatedKeyPair = await rsaService.generateKeyPair('Primary Test Key');
  });

  group('RSAKeyService Key Generation & Validation', () {
    test('generated key pair has valid PEM structure and 2048-bit modulus', () {
      expect(
        generatedKeyPair.publicKey,
        contains('-----BEGIN PUBLIC KEY-----'),
      );
      expect(generatedKeyPair.publicKey, contains('-----END PUBLIC KEY-----'));
      expect(
        generatedKeyPair.privateKey,
        contains('-----BEGIN PRIVATE KEY-----'),
      );
      expect(
        generatedKeyPair.privateKey,
        contains('-----END PRIVATE KEY-----'),
      );

      final keySize = rsaService.getKeySize(generatedKeyPair.publicKey);
      expect(keySize, equals(2048));
    });

    test(
      'validateKeyPair returns true for matching keys and false for mismatched/invalid keys',
      () async {
        final isValid = rsaService.validateKeyPair(
          generatedKeyPair.publicKey,
          generatedKeyPair.privateKey,
        );
        expect(isValid, isTrue);

        // Generate a second key to test mismatch
        final secondKeyPair = await rsaService.generateKeyPair('Second Key');
        final isMismatchValid = rsaService.validateKeyPair(
          generatedKeyPair.publicKey,
          secondKeyPair.privateKey,
        );
        expect(isMismatchValid, isFalse);

        // Malformed PEM strings
        expect(
          rsaService.validateKeyPair(
            'INVALID_PEM',
            generatedKeyPair.privateKey,
          ),
          isFalse,
        );
        expect(
          rsaService.validateKeyPair(generatedKeyPair.publicKey, 'INVALID_PEM'),
          isFalse,
        );
      },
    );

    test(
      'importKeyPair validates key match and stores key pair correctly',
      () async {
        const importedName = 'Imported Key';
        final imported = await rsaService.importKeyPair(
          name: importedName,
          publicKeyPem: generatedKeyPair.publicKey,
          privateKeyPem: generatedKeyPair.privateKey,
        );

        expect(imported.name, equals(importedName));
        expect(await rsaService.keyPairNameExists(importedName), isTrue);

        // Duplicate name throws Exception
        expect(
          () => rsaService.importKeyPair(
            name: importedName,
            publicKeyPem: generatedKeyPair.publicKey,
            privateKeyPem: generatedKeyPair.privateKey,
          ),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('RSA OAEP Encryption & Decryption', () {
    test(
      'encryptWithPublicKey and decryptWithPrivateKey round-trip successfully',
      () async {
        const plaintext = 'Secret message encrypted with RSA-OAEP!';
        final ciphertext = await rsaService.encryptWithPublicKey(
          plaintext,
          generatedKeyPair.publicKey,
        );

        expect(ciphertext, isNotEmpty);
        expect(ciphertext, isNot(equals(plaintext)));

        final decrypted = await rsaService.decryptWithPrivateKey(
          ciphertext,
          generatedKeyPair.privateKey,
        );
        expect(decrypted, equals(plaintext));
      },
    );

    test('decryptWithPrivateKey throws on corrupted ciphertext', () async {
      const plaintext = 'Sensitive payload';
      final ciphertext = await rsaService.encryptWithPublicKey(
        plaintext,
        generatedKeyPair.publicKey,
      );

      // Corrupt the ciphertext
      final tamperedCiphertext = ciphertext.replaceRange(
        10,
        15,
        ciphertext.substring(10, 15) == 'AAAAA' ? 'BBBBB' : 'AAAAA',
      );

      expect(
        () => rsaService.decryptWithPrivateKey(
          tamperedCiphertext,
          generatedKeyPair.privateKey,
        ),
        throwsA(anyOf(isA<ArgumentError>(), isA<Exception>())),
      );
    });
  });

  group('RSA-PSS Signatures & Verification', () {
    test(
      'signWithPrivateKey and verifyWithPublicKey succeed on valid message',
      () async {
        const message = 'Message to be digitally signed with RSA-PSS SHA-256';
        final signature = await rsaService.signWithPrivateKey(
          message,
          generatedKeyPair.privateKey,
        );

        expect(signature, isNotEmpty);

        final isValid = await rsaService.verifyWithPublicKey(
          message,
          signature,
          generatedKeyPair.publicKey,
        );
        expect(isValid, isTrue);
      },
    );

    test(
      'verifyWithPublicKey returns false on tampered message or tampered signature',
      () async {
        const message = 'Original message';
        final signature = await rsaService.signWithPrivateKey(
          message,
          generatedKeyPair.privateKey,
        );

        // Tampered message
        final isTamperedMessageValid = await rsaService.verifyWithPublicKey(
          'Tampered message!',
          signature,
          generatedKeyPair.publicKey,
        );
        expect(isTamperedMessageValid, isFalse);

        // Tampered signature
        final tamperedSignature = signature.replaceRange(
          5,
          10,
          signature.substring(5, 10) == 'AAAAA' ? 'BBBBB' : 'AAAAA',
        );
        final isTamperedSigValid = await rsaService.verifyWithPublicKey(
          message,
          tamperedSignature,
          generatedKeyPair.publicKey,
        );
        expect(isTamperedSigValid, isFalse);
      },
    );
  });

  group('RSA Hybrid Encryption (Large Payloads)', () {
    test(
      'encryptLargeData and decryptLargeData round-trip large text payloads',
      () async {
        final largeText = List.generate(
          100,
          (i) =>
              'Line $i: RSA Hybrid Encryption combines AES symmetric speed with RSA asymmetric key exchange.',
        ).join('\n');

        final package = await rsaService.encryptLargeData(
          largeText,
          generatedKeyPair.publicKey,
        );

        expect(package.containsKey('encryptedData'), isTrue);
        expect(package.containsKey('encryptedKey'), isTrue);
        expect(package.containsKey('iv'), isTrue);

        final decrypted = await rsaService.decryptLargeData(
          package,
          generatedKeyPair.privateKey,
        );
        expect(decrypted, equals(largeText));
      },
    );
  });
}
