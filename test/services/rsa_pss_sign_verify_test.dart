import 'dart:convert';
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
}
