import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/resources/global_resources.dart';
import 'package:qrypt/resources/obfuscation/built_in_obfuscation_maps.dart';
import 'package:qrypt/resources/obfuscation/built_in_v2_maps.dart';
import 'package:qrypt/services/aes_encryption.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/kem/kem_service.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUpAll(() {
    ObfuscationService.rebuildWith({
      ObfuscationMethod.en1: builtInEn1Map,
      ObfuscationMethod.en2: builtInEn2Map,
      ObfuscationMethod.fa1: builtInFa1Map,
      ObfuscationMethod.fa2: builtInFa2Map,
      for (final m in ObfuscationMethod.values)
        if (m.isV2Mapped) m: builtInV2MapForMethod(m),
    });
    TagManager.initializeTags();
  });

  group('ML-KEM Key Parsing & Validation Invariants', () {
    final kemService = KemKeyService();
    late QryptKEMKeyPair recipientKeyPair;
    late Uint8List senderSharedSecret;
    late String senderSharedSecretBase64;
    late String senderSharedSecretHex;

    setUpAll(() async {
      recipientKeyPair = await kemService.generateKeyPair('Recipient');
      final encResult = kemService.encapsulateWithPublicKey(
        recipientKeyPair.publicKey,
      );
      senderSharedSecret = encResult.sharedSecret;
      expect(senderSharedSecret.length, equals(32));

      senderSharedSecretBase64 = base64.encode(senderSharedSecret);
      expect(senderSharedSecretBase64.length, equals(44));

      senderSharedSecretHex = senderSharedSecret
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(senderSharedSecretHex.length, equals(64));
    });

    test('validateAesKey accepts 44-char Base64 and 64-char Hex 256-bit keys', () {
      expect(validateAesKey(senderSharedSecretBase64), isNull);
      expect(validateAesKey(senderSharedSecretHex), isNull);
      expect(validateAesKey('1234567890123456'), isNull); // 16 bytes
      expect(validateAesKey('123456789012345678901234'), isNull); // 24 bytes
      expect(validateAesKey('12345678901234567890123456789012'), isNull); // 32 bytes

      // Rejects invalid lengths or non-hex / non-base64
      expect(validateAesKey('short'), isNotNull);
      expect(validateAesKey('Z' * 64), isNotNull); // 64 chars but not hex
    });

    test('parseAesKey correctly derives 256-bit Key from Base64 and Hex', () {
      final keyFromBase64 = parseAesKey(senderSharedSecretBase64);
      final keyFromHex = parseAesKey(senderSharedSecretHex);

      expect(keyFromBase64.bytes, equals(senderSharedSecret));
      expect(keyFromHex.bytes, equals(senderSharedSecret));
    });

    test('AESKey model reports 32 byteLength and 256 bitLength for KEM secrets', () {
      final aesKeyB64 = AESKey(
        id: '1',
        name: 'KEM Base64',
        key: senderSharedSecretBase64,
        createdAt: DateTime.now(),
      );
      expect(aesKeyB64.byteLength, equals(32));
      expect(aesKeyB64.bitLength, equals(256));

      final aesKeyHex = AESKey(
        id: '2',
        name: 'KEM Hex',
        key: senderSharedSecretHex,
        createdAt: DateTime.now(),
      );
      expect(aesKeyHex.byteLength, equals(32));
      expect(aesKeyHex.bitLength, equals(256));
    });
  });

  group('ML-KEM Pipeline Roundtrip & Routing Invariants', () {
    final ih = InputHandler();
    final kemService = KemKeyService();

    test('Qrypt.withKem enforces compression=none', () {
      final q = Qrypt.withKem(
        text: 'Optional note',
        obfuscation: ObfuscationMethod.en2,
        sign: SignMethod.none,
        useTag: true,
        kemReceiverPublicKey: 'dummy',
      );
      expect(q.encryption, equals(EncryptionMethod.mlKem));
      expect(q.compression, equals(CompressionMethod.none));
    });

    for (final obf in [
      ObfuscationMethod.none,
      ObfuscationMethod.b64,
      ObfuscationMethod.en1,
      ObfuscationMethod.en2,
    ]) {
      test('ML-KEM end-to-end roundtrip with obfuscation ${obf.name}', () async {
        // 1. Recipient generates keypair
        final recipientKeys = await kemService.generateKeyPair(
          'Alice_${obf.name}',
        );
        final recipientPubKeyBase64 = base64.encode(recipientKeys.publicKey);

        // 2. Sender encapsulates into Qrypt pipeline
        final senderQ = Qrypt.withKem(
          text: '',
          obfuscation: obf,
          sign: SignMethod.none,
          useTag: true,
          kemReceiverPublicKey: recipientPubKeyBase64,
        );

        final processedSender = await ih.handleProcess(senderQ);

        expect(processedSender.kemSharedSecret, isNotNull);
        expect(processedSender.kemSharedSecret!.length, equals(32));
        expect(processedSender.ciphertext, isNotNull);
        expect(processedSender.ciphertext!.length, equals(1088)); // NIST ML-KEM-768 ciphertext

        final wirePayload = processedSender.text;
        expect(wirePayload, isNotEmpty);

        // 3. Recipient receives wirePayload and decrypts with Tag auto-detection
        final receiverQ = Qrypt.autoDecrypt(text: wirePayload);
        receiverQ.kemKeyPair = recipientKeys;

        final processedReceiver = await ih.handleDeProcess(null, receiverQ, true);

        // Assert shared secrets match exactly
        expect(processedReceiver.kemSharedSecret, equals(processedSender.kemSharedSecret));
        expect(processedReceiver.ciphertext, equals(processedSender.ciphertext));

        // 4. Test using the shared secret immediately in AES-GCM
        final sharedSecretKeyString = base64.encode(processedSender.kemSharedSecret!);

        const message = 'Secret message protected by ML-KEM-negotiated AES key';
        final aesEncryptQ = Qrypt.withTag(
          text: message,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.en2,
          compression: CompressionMethod.gZip,
          sign: SignMethod.none,
          useTag: true,
        );
        aesEncryptQ.customKey = sharedSecretKeyString;
        aesEncryptQ.useCustomKey = true;

        final aesEncrypted = await ih.handleProcess(aesEncryptQ);

        final aesDecryptQ = Qrypt.autoDecrypt(text: aesEncrypted.text);
        aesDecryptQ.customKey = sharedSecretKeyString;
        aesDecryptQ.useCustomKey = true;

        final aesDecrypted = await ih.handleDeProcess(null, aesDecryptQ, true);
        expect(aesDecrypted.text, equals(message));
      });
    }
  });
}
