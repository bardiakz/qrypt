import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.loadAllTags();
  });

  group('EncryptionMethod.isUserSelectable', () {
    test('rsaSign is not user selectable, all others are', () {
      expect(EncryptionMethod.rsaSign.isUserSelectable, isFalse);
      expect(EncryptionMethod.none.isUserSelectable, isTrue);
      expect(EncryptionMethod.aesCbc.isUserSelectable, isTrue);
      expect(EncryptionMethod.aesCtr.isUserSelectable, isTrue);
      expect(EncryptionMethod.aesGcm.isUserSelectable, isTrue);
      expect(EncryptionMethod.rsa.isUserSelectable, isTrue);
      expect(EncryptionMethod.mlKem.isUserSelectable, isTrue);
    });
  });

  group('SignMethod.rsaPss displayName', () {
    test('rsaPss has correct display name', () {
      expect(SignMethod.rsaPss.displayName, equals('RSA-PSS (SHA-256)'));
    });
  });

  group('InputHandler.handleVerify RSA-PSS fail-closed tests', () {
    testWidgets('throws when RSA public key is missing', (tester) async {
      final ih = InputHandler();
      final qrypt = Qrypt(
        text: 'dummy_payload',
        sign: SignMethod.rsaPss,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.none,
        compression: CompressionMethod.none,
      );
      qrypt.rsaVerifyPublicKey = null;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(key: Key('target'))),
        ),
      );

      final context = tester.element(find.byKey(const Key('target')));

      expect(
        () => ih.handleVerify(qrypt, context),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('RSA public key is required'),
          ),
        ),
      );
    });

    testWidgets('throws when signature verification fails (tampered package)', (
      tester,
    ) async {
      final ih = InputHandler();
      final rsa = RSAKeyService();
      final keyPair = await rsa.generateKeyPair('test_verify_pair');

      const originalPayload = 'ciphertext123:iv456';
      final originalMessage = utf8.encode(originalPayload);
      final messageToSign = base64Encode(originalMessage);
      final validSignature = await rsa.signWithPrivateKey(
        messageToSign,
        keyPair.privateKey,
      );

      // Tamper with the message but keep the signature
      const tamperedPayload = 'tampered_ciphertext:iv456';
      final tamperedMessage = utf8.encode(tamperedPayload);
      final packageJson = jsonEncode({
        'message': base64Encode(tamperedMessage),
        'signature': validSignature,
      });

      final qrypt = Qrypt(
        text: base64Encode(utf8.encode(packageJson)),
        sign: SignMethod.rsaPss,
        obfuscation: ObfuscationMethod.none,
        encryption: EncryptionMethod.aesGcm,
        compression: CompressionMethod.none,
      );
      qrypt.rsaVerifyPublicKey = keyPair.publicKey;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(key: Key('target'))),
        ),
      );

      final context = tester.element(find.byKey(const Key('target')));

      expect(
        () => ih.handleVerify(qrypt, context),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('RSA-PSS signature verification failed'),
          ),
        ),
      );
    });

    testWidgets('succeeds and extracts payload when signature is valid', (
      tester,
    ) async {
      final ih = InputHandler();
      final rsa = RSAKeyService();
      final keyPair = await rsa.generateKeyPair('test_valid_pair');

      const expectedPayload = 'ciphertext123:iv456';
      final originalMessage = utf8.encode(expectedPayload);
      final messageToSign = base64Encode(originalMessage);
      final validSignature = await rsa.signWithPrivateKey(
        messageToSign,
        keyPair.privateKey,
      );

      final packageJson = jsonEncode({
        'message': messageToSign,
        'signature': validSignature,
      });

      final qrypt = Qrypt(
        text: base64Encode(utf8.encode(packageJson)),
        sign: SignMethod.rsaPss,
        obfuscation: ObfuscationMethod.none,
        encryption: EncryptionMethod.aesGcm,
        compression: CompressionMethod.none,
      );
      qrypt.rsaVerifyPublicKey = keyPair.publicKey;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(key: Key('target'))),
        ),
      );

      final context = tester.element(find.byKey(const Key('target')));

      final result = await ih.handleVerify(qrypt, context);
      expect(result.text, equals(expectedPayload));
    });
  });

  group('Full Pipeline Encrypt-then-Sign with RSA-PSS', () {
    testWidgets('AES-GCM + RSA-PSS sign + GZip + Tag roundtrip', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(key: Key('target'))),
        ),
      );
      final context = tester.element(find.byKey(const Key('target')));

      final ih = InputHandler();
      final rsa = RSAKeyService();
      final signKeyPair = await rsa.generateKeyPair('pipeline_sign_key');

      const plaintext = 'Sensitive top-secret message to sign with RSA-PSS';
      const aesKey = '0123456789abcdef0123456789abcdef';

      final encryptQrypt = Qrypt.withTag(
        text: plaintext,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.b64,
        compression: CompressionMethod.gZip,
        sign: SignMethod.rsaPss,
        useTag: true,
      );
      encryptQrypt.customKey = aesKey;
      encryptQrypt.useCustomKey = true;
      encryptQrypt.rsaSignKeyPair = signKeyPair;

      final processed = await ih.handleProcess(encryptQrypt);
      expect(processed.text, isNotEmpty);
      expect(TagManager.matchedTag(processed.text), isNotNull);

      // Decrypt side
      final decryptQrypt = Qrypt.autoDecrypt(text: processed.text);
      decryptQrypt.customKey = aesKey;
      decryptQrypt.useCustomKey = true;
      decryptQrypt.rsaVerifyPublicKey = signKeyPair.publicKey;

      final deProcessed = await ih.handleDeProcess(
        context,
        decryptQrypt,
        true,
      );
      expect(deProcessed.text, equals(plaintext));
    });
  });

  group('Legacy rsaSign decode fail-closed verification', () {
    testWidgets('handleDecrypt throws when rsaSign signature is invalid', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(key: Key('target'))),
        ),
      );
      final context = tester.element(find.byKey(const Key('target')));

      final ih = InputHandler();
      final rsa = RSAKeyService();
      final senderKeyPair = await rsa.generateKeyPair('rsa_sign_sender');
      final receiverKeyPair = await rsa.generateKeyPair('rsa_sign_receiver');
      final wrongKeyPair = await rsa.generateKeyPair('rsa_sign_wrong');

      final encryptQrypt = Qrypt(
        text: 'Top secret data for rsaSign',
        encryption: EncryptionMethod.rsaSign,
        obfuscation: ObfuscationMethod.b64,
        compression: CompressionMethod.none,
        sign: SignMethod.none,
      );
      encryptQrypt.compressedText = utf8.encode('Top secret data for rsaSign');
      encryptQrypt.rsaKeyPair = senderKeyPair; // used to sign in rsaSign
      encryptQrypt.rsaReceiverPublicKey = receiverKeyPair.publicKey; // used to encrypt

      final encryptedQrypt = await ih.handleEncrypt(encryptQrypt);

      // Now attempt decrypt with receiver private key but WRONG sender public key
      final decryptQrypt = Qrypt(
        text: encryptedQrypt.text,
        encryption: EncryptionMethod.rsaSign,
        obfuscation: ObfuscationMethod.b64,
        compression: CompressionMethod.none,
        sign: SignMethod.none,
      );
      decryptQrypt.rsaKeyPair = receiverKeyPair;
      // Set sender public key to the wrong key
      decryptQrypt.rsaSenderPublicKey = wrongKeyPair.publicKey;

      expect(
        () => ih.handleDecrypt(decryptQrypt, context),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('RSA+Sign decryption failed'),
          ),
        ),
      );
      expect(decryptQrypt.deCompressedText.isEmpty, isTrue);
    });
  });

  group('RSASSA-PSS Direct Sign & Verify & Negative Controls', () {
    test('sign and verify roundtrip across multiple payload lengths', () async {
      final rsa = RSAKeyService();
      final keyPair = await rsa.generateKeyPair('pss_direct_test_pair');

      final testMessages = <String, String>{
        'Empty message': '',
        'Single character': 'A',
        'Medium message': 'The quick brown fox jumps over the lazy dog',
        'Large message': 'Repeating data payload: ' * 100,
      };

      for (final entry in testMessages.entries) {
        final message = entry.value;
        final signature = await rsa.signWithPrivateKey(message, keyPair.privateKey);
        expect(signature, isNotEmpty);

        final isValid = await rsa.verifyWithPublicKey(
          message,
          signature,
          keyPair.publicKey,
        );
        expect(isValid, isTrue, reason: 'Failed for ${entry.key}');

        // Negative Control 1: Tampered message fails verification
        final tamperedMessage = '${message}_tampered';
        final isTamperedValid = await rsa.verifyWithPublicKey(
          tamperedMessage,
          signature,
          keyPair.publicKey,
        );
        expect(isTamperedValid, isFalse, reason: 'Tampered message should fail for ${entry.key}');

        // Negative Control 2: Tampered signature fails verification
        final sigBytes = base64.decode(signature);
        sigBytes[sigBytes.length ~/ 2] ^= 0xFF;
        final tamperedSignature = base64.encode(sigBytes);
        final isTamperedSigValid = await rsa.verifyWithPublicKey(
          message,
          tamperedSignature,
          keyPair.publicKey,
        );
        expect(isTamperedSigValid, isFalse, reason: 'Tampered signature should fail for ${entry.key}');
      }
    });

    test('verifies failure on corrupted signature or invalid PEM gracefully', () async {
      final rsa = RSAKeyService();
      final keyPair = await rsa.generateKeyPair('pss_corrupt_test_pair');

      final isValidCorruptSig = await rsa.verifyWithPublicKey(
        'test message',
        'not_a_valid_base64_signature!',
        keyPair.publicKey,
      );
      expect(isValidCorruptSig, isFalse);

      final isValidBadKey = await rsa.verifyWithPublicKey(
        'test message',
        base64.encode(Uint8List(256)),
        'not_a_valid_pem',
      );
      expect(isValidBadKey, isFalse);
    });
  });

  group('OpenSSL 3 Bidirectional RSASSA-PSS Interoperability', () {
    bool isOpenSslAvailable() {
      try {
        final result = Process.runSync('openssl', ['version']);
        return result.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    test('PointyCastle and OpenSSL 3 verify each other bidirectionally with negative controls', () async {
      if (!isOpenSslAvailable()) {
        return; // Skipped dynamically when openssl binary is not present on PATH
      }

      final tempDir = Directory.systemTemp.createTempSync('openssl_pss_test');
      try {
        final rsa = RSAKeyService();
        final keyPair = await rsa.generateKeyPair('openssl_interop_key');

        final testMessage = 'OpenSSL 3 RSASSA-PSS interop verification payload';
        final testMessageBytes = utf8.encode(testMessage);

        // 1. Qrypt signs with PointyCastle PSS -> OpenSSL 3 verifies
        final qryptSignatureBase64 = await rsa.signWithPrivateKey(
          testMessage,
          keyPair.privateKey,
        );
        final qryptSigBytes = base64.decode(qryptSignatureBase64);

        final msgFile = File('${tempDir.path}/msg.bin')..writeAsBytesSync(testMessageBytes);
        final sigFile = File('${tempDir.path}/sig.bin')..writeAsBytesSync(qryptSigBytes);
        final pubKeyFile = File('${tempDir.path}/pub.pem')..writeAsStringSync(keyPair.publicKey);

        final opensslVerify = Process.runSync('openssl', [
          'dgst',
          '-sha256',
          '-sigopt', 'rsa_padding_mode:pss',
          '-sigopt', 'rsa_pss_saltlen:32',
          '-sigopt', 'rsa_mgf1_md:sha256',
          '-verify', pubKeyFile.path,
          '-signature', sigFile.path,
          msgFile.path,
        ]);
        expect(opensslVerify.exitCode, equals(0), reason: 'OpenSSL failed to verify Qrypt PSS signature');

        // Negative Control with OpenSSL: Tampered message rejected
        final tamperedMsgFile = File('${tempDir.path}/tampered_msg.bin')
          ..writeAsBytesSync(Uint8List.fromList(List.from(testMessageBytes)..[0] ^= 0xFF));
        final opensslTamperedVerify = Process.runSync('openssl', [
          'dgst',
          '-sha256',
          '-sigopt', 'rsa_padding_mode:pss',
          '-sigopt', 'rsa_pss_saltlen:32',
          '-sigopt', 'rsa_mgf1_md:sha256',
          '-verify', pubKeyFile.path,
          '-signature', sigFile.path,
          tamperedMsgFile.path,
        ]);
        expect(opensslTamperedVerify.exitCode, isNot(equals(0)));

        // 2. OpenSSL signs with PSS -> Qrypt verifies with PointyCastle
        final privKeyFile = File('${tempDir.path}/priv.pem')..writeAsStringSync(keyPair.privateKey);
        final opensslSigFile = File('${tempDir.path}/openssl_sig.bin');

        final opensslSign = Process.runSync('openssl', [
          'dgst',
          '-sha256',
          '-sigopt', 'rsa_padding_mode:pss',
          '-sigopt', 'rsa_pss_saltlen:32',
          '-sigopt', 'rsa_mgf1_md:sha256',
          '-sign', privKeyFile.path,
          '-out', opensslSigFile.path,
          msgFile.path,
        ]);
        expect(opensslSign.exitCode, equals(0), reason: 'OpenSSL failed to sign with PSS');

        final opensslSigBytes = opensslSigFile.readAsBytesSync();
        final opensslSigBase64 = base64.encode(opensslSigBytes);

        final qryptVerifyResult = await rsa.verifyWithPublicKey(
          testMessage,
          opensslSigBase64,
          keyPair.publicKey,
        );
        expect(qryptVerifyResult, isTrue, reason: 'Qrypt failed to verify OpenSSL PSS signature');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
