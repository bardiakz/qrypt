import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oqs/oqs.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/services/aes/aes_key_storage_service.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/kem/kem_key_storage_service.dart';
import 'package:qrypt/services/ml_dsa/ml_dsa_key_service.dart';
import 'package:qrypt/services/ml_dsa/ml_dsa_key_storage_service.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/obfuscation/obfuscation_map_repository.dart';
import 'package:qrypt/services/oqs_bridge.dart' as bridge;
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/rsa/rsa_key_storage_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InputHandler ih;
  late RSAKeyService rsaService;
  late RSAKeyPair rsaKeyPair;

  var libOqsAvailable = false;
  try {
    LibOQSLoader.customPaths = LibraryPaths.fromReleaseArchive('liboqs-0.16.0');
    LibOQS.init();
    libOqsAvailable = true;
  } catch (_) {
    libOqsAvailable = false;
  }
  final String? libOqsSkipReason = libOqsAvailable
      ? null
      : 'Native liboqs library is not installed on this host';

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    Compression.setNativeLibPaths();
    TagManager.loadAllTags();

    ih = InputHandler();
    rsaService = RSAKeyService();
    rsaKeyPair = await rsaService.generateKeyPair('Tier1-RSA', keySize: 2048);
  });

  group('[C-01 / H-01] ML-DSA Multi-Parameter Set Validation & Roundtrip', () {
    test('detects algorithm from public and secret key byte lengths', () {
      expect(
        MlDsaKeyService.algorithmFromPublicKeyLength(1312),
        equals('ML-DSA-44'),
      );
      expect(
        MlDsaKeyService.algorithmFromPublicKeyLength(1952),
        equals('ML-DSA-65'),
      );
      expect(
        MlDsaKeyService.algorithmFromPublicKeyLength(2592),
        equals('ML-DSA-87'),
      );
      expect(MlDsaKeyService.algorithmFromPublicKeyLength(100), isNull);

      expect(
        MlDsaKeyService.algorithmFromSecretKeyLength(2560),
        equals('ML-DSA-44'),
      );
      expect(
        MlDsaKeyService.algorithmFromSecretKeyLength(4032),
        equals('ML-DSA-65'),
      );
      expect(
        MlDsaKeyService.algorithmFromSecretKeyLength(4896),
        equals('ML-DSA-87'),
      );
      expect(MlDsaKeyService.algorithmFromSecretKeyLength(100), isNull);
    });

    for (final algorithm in MlDsaKeyService.supportedParameterSets) {
      test(
        'validateKeyPair and InputHandler sign/verify work end-to-end for $algorithm',
        () async {
          final service = MlDsaKeyService(algorithm: algorithm);
          final sig = bridge.Signature.create(algorithm);
          try {
            final kp1 = sig.generateKeyPair();
            final kp2 = sig.generateKeyPair();

            final mismatchedSigPair = bridge.SignatureKeyPair(
              publicKey: kp1.publicKey,
              secretKey: kp2.secretKey,
            );
            final wrongSizeSigPair = bridge.SignatureKeyPair(
              publicKey: Uint8List(32),
              secretKey: Uint8List(64),
            );

            expect(await service.validateKeyPair(kp1), isTrue);
            expect(await service.validateKeyPair(mismatchedSigPair), isFalse);
            expect(await service.validateKeyPair(wrongSizeSigPair), isFalse);

            final validPair = QryptMLDSAKeyPair.fromComponents(
              name: '$algorithm-valid',
              algorithm: algorithm,
              publicKey: kp1.publicKey,
              secretKey: kp1.secretKey,
            );

            // End-to-end InputHandler sign + headless verify
            const secretText = 'Post-quantum signed message';
            const aesKey = '0123456789abcdef0123456789abcdef';
            final encryptQrypt = Qrypt.withTag(
              text: secretText,
              encryption: EncryptionMethod.aesGcm,
              obfuscation: ObfuscationMethod.none,
              compression: CompressionMethod.none,
              sign: SignMethod.mlDsa,
              useTag: false,
            )
              ..customKey = aesKey
              ..useCustomKey = true
              ..dsaKeyPair = validPair;
            final signed = await ih.handleProcess(encryptQrypt);

            final decryptQrypt = Qrypt.withTag(
              text: signed.text,
              encryption: EncryptionMethod.aesGcm,
              obfuscation: ObfuscationMethod.none,
              compression: CompressionMethod.none,
              sign: SignMethod.mlDsa,
              useTag: false,
            )
              ..customKey = aesKey
              ..useCustomKey = true
              ..dsaVerifyPublicKey = validPair.publicKey;
            final verified = await ih.handleDeProcess(
              null,
              decryptQrypt,
              false,
            );
            expect(verified.text, equals(secretText));

            // Wrong public key from same algorithm must fail closed
            final wrongKeyDecrypt = Qrypt.withTag(
              text: signed.text,
              encryption: EncryptionMethod.aesGcm,
              obfuscation: ObfuscationMethod.none,
              compression: CompressionMethod.none,
              sign: SignMethod.mlDsa,
              useTag: false,
            )
              ..customKey = aesKey
              ..useCustomKey = true
              ..dsaVerifyPublicKey = kp2.publicKey;
            await expectLater(
              () => ih.handleDeProcess(null, wrongKeyDecrypt, false),
              throwsA(isA<Exception>()),
            );
          } finally {
            sig.dispose();
            service.dispose();
          }
        },
        skip: libOqsSkipReason,
      );
    }

    test(
      'stored ML-DSA-44 and ML-DSA-87 keys sign/verify via default service',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        const storage = MlDsaKeyStorageService();
        final service44 = MlDsaKeyService(
          storageService: storage,
          algorithm: 'ML-DSA-44',
        );
        final service87 = MlDsaKeyService(
          storageService: storage,
          algorithm: 'ML-DSA-87',
        );
        final defaultService = MlDsaKeyService(storageService: storage);

        try {
          final kp44 = await service44.generateKeyPair('Key-44');
          final kp87 = await service87.generateKeyPair('Key-87');
          final msg = Uint8List.fromList(
            utf8.encode('mixed parameter set test'),
          );

          final sig44 = await defaultService.signMessageWithStoredKey(
            msg,
            kp44.id,
          );
          expect(
            await defaultService.verifySignatureWithStoredKey(
              msg,
              sig44,
              kp44.id,
            ),
            isTrue,
          );

          final sig87 = await defaultService.signMessageWithStoredKey(
            msg,
            kp87.id,
          );
          expect(
            await defaultService.verifySignatureWithStoredKey(
              msg,
              sig87,
              kp87.id,
            ),
            isTrue,
          );
        } finally {
          service44.dispose();
          service87.dispose();
          defaultService.dispose();
        }
      },
      skip: libOqsSkipReason,
    );
  });

  group('[H-02] Headless (context == null) Signature Verification Fail-Closed', () {
    const aesKey = '0123456789abcdef0123456789abcdef';

    test('RSA-PSS tagged and untagged payloads fail closed when tampered with context == null', () async {
      const plaintext = 'Authenticated RSA-PSS payload';
      for (final useTag in [false, true]) {
        final encryptQrypt = Qrypt.withTag(
          text: plaintext,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.rsaPss,
          useTag: useTag,
        )
          ..customKey = aesKey
          ..useCustomKey = true
          ..rsaSignKeyPair = rsaKeyPair;

        final processed = await ih.handleProcess(encryptQrypt);

        // Valid verification succeeds with context == null
        final okQrypt = Qrypt.withTag(
          text: processed.text,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.rsaPss,
          useTag: useTag,
        )
          ..customKey = aesKey
          ..useCustomKey = true
          ..rsaVerifyPublicKey = rsaKeyPair.publicKey;
        final ok = await ih.handleDeProcess(null, okQrypt, useTag);
        expect(ok.text, equals(plaintext));

        // Missing verify key fails closed with context == null
        final missingKeyQrypt = Qrypt.withTag(
          text: processed.text,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.rsaPss,
          useTag: useTag,
        )
          ..customKey = aesKey
          ..useCustomKey = true;
        await expectLater(
          () => ih.handleDeProcess(null, missingKeyQrypt, useTag),
          throwsA(isA<Exception>()),
        );

        // Tampered payload fails closed with context == null
        final tampered =
            processed.text.substring(0, processed.text.length - 4) +
            (processed.text.endsWith('AAAA') ? 'BBBB' : 'AAAA');
        final tamperedQrypt = Qrypt.withTag(
          text: tampered,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.rsaPss,
          useTag: useTag,
        )
          ..customKey = aesKey
          ..useCustomKey = true
          ..rsaVerifyPublicKey = rsaKeyPair.publicKey;
        await expectLater(
          () => ih.handleDeProcess(null, tamperedQrypt, useTag),
          throwsA(isA<Exception>()),
        );
      }
    });

    test(
      'ML-DSA tagged payload verifies and fails closed with context == null',
      () async {
        final sig = bridge.Signature.create('ML-DSA-65');
        try {
          final rawKp = sig.generateKeyPair();
          final kp = QryptMLDSAKeyPair.fromComponents(
            name: 'Headless-Tagged-65',
            algorithm: 'ML-DSA-65',
            publicKey: rawKp.publicKey,
            secretKey: rawKp.secretKey,
          );
          const plaintext = 'Tagged ML-DSA headless test';
          final encryptQrypt = Qrypt.withTag(
            text: plaintext,
            encryption: EncryptionMethod.aesGcm,
            obfuscation: ObfuscationMethod.none,
            compression: CompressionMethod.none,
            sign: SignMethod.mlDsa,
            useTag: true,
          )
            ..customKey = aesKey
            ..useCustomKey = true
            ..dsaKeyPair = kp;
          final processed = await ih.handleProcess(encryptQrypt);

          final verifyQrypt = Qrypt.withTag(
            text: processed.text,
            encryption: EncryptionMethod.aesGcm,
            obfuscation: ObfuscationMethod.none,
            compression: CompressionMethod.none,
            sign: SignMethod.mlDsa,
            useTag: true,
          )
            ..customKey = aesKey
            ..useCustomKey = true
            ..dsaVerifyPublicKey = kp.publicKey;
          final verified = await ih.handleDeProcess(null, verifyQrypt, true);
          expect(verified.text, equals(plaintext));

          // Missing public key must throw (never silently skip verify!)
          final missingKeyQrypt = Qrypt.withTag(
            text: processed.text,
            encryption: EncryptionMethod.aesGcm,
            obfuscation: ObfuscationMethod.none,
            compression: CompressionMethod.none,
            sign: SignMethod.mlDsa,
            useTag: true,
          )
            ..customKey = aesKey
            ..useCustomKey = true;
          await expectLater(
            () => ih.handleDeProcess(null, missingKeyQrypt, true),
            throwsA(isA<Exception>()),
          );
        } finally {
          sig.dispose();
        }
      },
      skip: libOqsSkipReason,
    );
  });

  group('[M-08a] Secure Storage Services Refuse to Wipe Corrupt Keystores', () {
    const corruptJson = '{corrupt_json_that_must_not_be_overwritten';

    test('AesKeyStorageService throws and preserves raw entry on corrupt JSON', () async {
      FlutterSecureStorage.setMockInitialValues({'aes_keys': corruptJson});
      const storage = FlutterSecureStorage();
      const aesStorage = AesKeyStorageService(storage: storage);

      final newKey = AESKey(
        id: 'new-id',
        name: 'New Key',
        key: 'a' * 32,
        createdAt: DateTime.now(),
      );

      await expectLater(() => aesStorage.saveKey(newKey), throwsA(anything));
      await expectLater(() => aesStorage.deleteKey('new-id'), throwsA(anything));
      await expectLater(() => aesStorage.updateKey(newKey), throwsA(anything));
      expect(await storage.read(key: 'aes_keys'), equals(corruptJson));
    });

    test('RSAKeyStorageService throws and preserves raw entry on corrupt JSON', () async {
      FlutterSecureStorage.setMockInitialValues({'rsa_key_pairs': corruptJson});
      const storage = FlutterSecureStorage();
      const rsaStorage = RSAKeyStorageService(storage: storage);

      await expectLater(
        () => rsaStorage.saveKeyPair(rsaKeyPair),
        throwsA(anything),
      );
      await expectLater(
        () => rsaStorage.deleteKeyPair(rsaKeyPair.id),
        throwsA(anything),
      );
      await expectLater(
        () => rsaStorage.updateKeyPair(rsaKeyPair),
        throwsA(anything),
      );
      expect(await storage.read(key: 'rsa_key_pairs'), equals(corruptJson));
    });

    test('KemKeyStorageService throws and preserves raw entry on corrupt JSON', () async {
      FlutterSecureStorage.setMockInitialValues({'kem_key_pairs': corruptJson});
      const storage = FlutterSecureStorage();
      const kemStorage = KemKeyStorageService(storage: storage);

      final kp = QryptKEMKeyPair.create(
        name: 'KEM-Test',
        kemKeyPair: bridge.KEMKeyPair(
          publicKey: Uint8List.fromList([1, 2, 3]),
          secretKey: Uint8List.fromList([4, 5, 6]),
        ),
        algorithm: 'ML-KEM-768',
      );

      await expectLater(() => kemStorage.saveKeyPair(kp), throwsA(anything));
      await expectLater(() => kemStorage.deleteKeyPair(kp.id), throwsA(anything));
      await expectLater(() => kemStorage.updateKeyPair(kp), throwsA(anything));
      expect(await storage.read(key: 'kem_key_pairs'), equals(corruptJson));
    });

    test('MlDsaKeyStorageService throws and preserves raw entry on corrupt JSON', () async {
      FlutterSecureStorage.setMockInitialValues({
        'mldsa_key_pairs': corruptJson,
      });
      const storage = FlutterSecureStorage();
      const dsaStorage = MlDsaKeyStorageService(storage: storage);

      final kp = QryptMLDSAKeyPair.fromComponents(
        name: 'DSA-Test',
        algorithm: 'ML-DSA-65',
        publicKey: Uint8List.fromList([1, 2, 3]),
        secretKey: Uint8List.fromList([4, 5, 6]),
      );

      await expectLater(() => dsaStorage.saveKeyPair(kp), throwsA(anything));
      await expectLater(() => dsaStorage.deleteKeyPair(kp.id), throwsA(anything));
      await expectLater(() => dsaStorage.updateKeyPair(kp), throwsA(anything));
      expect(await storage.read(key: 'mldsa_key_pairs'), equals(corruptJson));
    });

    test('ObfuscationMapRepository throws and preserves raw entry on corrupt JSON', () async {
      FlutterSecureStorage.setMockInitialValues({
        'custom_obfuscation_profiles_v1': corruptJson,
      });
      const storage = FlutterSecureStorage();

      await expectLater(
        () => ObfuscationMapRepository.instance.setCustomMap(
          ObfuscationMethod.en1,
          const {'a': 'x'},
        ),
        throwsA(anything),
      );
      await expectLater(
        () => ObfuscationMapRepository.instance.clearCustomMap(
          ObfuscationMethod.en1,
        ),
        throwsA(anything),
      );
      expect(
        await storage.read(key: 'custom_obfuscation_profiles_v1'),
        equals(corruptJson),
      );
    });
  });

  group('[L-04] QryptKEMKeyPair UUID v4 IDs', () {
    test('generates valid distinct UUID v4 identifiers', () {
      final uuidV4Pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final raw = bridge.KEMKeyPair(
        publicKey: Uint8List.fromList([1]),
        secretKey: Uint8List.fromList([2]),
      );
      final first = QryptKEMKeyPair.create(name: 'A', kemKeyPair: raw);
      final second = QryptKEMKeyPair.create(name: 'B', kemKeyPair: raw);

      expect(uuidV4Pattern.hasMatch(first.id), isTrue);
      expect(uuidV4Pattern.hasMatch(second.id), isTrue);
      expect(first.id, isNot(equals(second.id)));
    });
  });
}
