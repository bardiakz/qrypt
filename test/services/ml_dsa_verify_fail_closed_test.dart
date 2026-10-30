import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oqs/oqs.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/ml_dsa/ml_dsa_key_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LibOQSLoader.customPaths = LibraryPaths.fromReleaseArchive('liboqs-0.16.0');
    LibOQS.init();
  });

  group('InputHandler.handleVerify ML-DSA tests', () {
    testWidgets('throws when public key is missing', (tester) async {
      final ih = InputHandler();
      final qrypt = Qrypt(
        text: 'dummy_payload',
        sign: SignMethod.mlDsa,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.none,
        compression: CompressionMethod.none,
      );
      qrypt.dsaVerifyPublicKEy = null;

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
            contains('ML-DSA public key is required'),
          ),
        ),
      );
    });

    testWidgets('throws when signature verification fails (tampered package)', (
      tester,
    ) async {
      final ih = InputHandler();
      final dsa = MlDsaKeyService();
      final sig = Signature.create('ML-DSA-65');
      final keyPair = sig.generateKeyPair();

      // Create a valid signed message first
      final originalMessage = utf8.encode('ciphertext123:iv456');
      final validSignature = dsa.signMessage(
        originalMessage,
        keyPair.secretKey,
      );

      // Tamper with the message but keep the signature
      final tamperedMessage = utf8.encode('tampered_text:iv456');
      final packageJson = jsonEncode({
        'message': base64Encode(tamperedMessage),
        'signature': base64Encode(validSignature),
      });

      final qrypt = Qrypt(
        text: base64Encode(utf8.encode(packageJson)),
        sign: SignMethod.mlDsa,
        obfuscation: ObfuscationMethod.none,
        encryption: EncryptionMethod.aesGcm,
        compression: CompressionMethod.none,
      );
      qrypt.dsaVerifyPublicKEy = keyPair.publicKey;

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
            contains('ML-DSA signature verification failed'),
          ),
        ),
      );
    });

    testWidgets('succeeds and extracts payload when signature is valid', (
      tester,
    ) async {
      final ih = InputHandler();
      final dsa = MlDsaKeyService();
      final sig = Signature.create('ML-DSA-65');
      final keyPair = sig.generateKeyPair();

      const expectedPayload = 'ciphertext123:iv456';
      final originalMessage = utf8.encode(expectedPayload);
      final validSignature = dsa.signMessage(
        originalMessage,
        keyPair.secretKey,
      );

      final packageJson = jsonEncode({
        'message': base64Encode(originalMessage),
        'signature': base64Encode(validSignature),
      });

      final qrypt = Qrypt(
        text: base64Encode(utf8.encode(packageJson)),
        sign: SignMethod.mlDsa,
        obfuscation: ObfuscationMethod.none,
        encryption: EncryptionMethod.aesGcm,
        compression: CompressionMethod.none,
      );
      qrypt.dsaVerifyPublicKEy = keyPair.publicKey;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(key: Key('target'))),
        ),
      );

      final context = tester.element(find.byKey(const Key('target')));

      final result = ih.handleVerify(qrypt, context);
      expect(result.text, equals(expectedPayload));
    });
  });
}
