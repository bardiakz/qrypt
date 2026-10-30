import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/exceptions.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/services/aes/aes_key_storage_service.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    Compression.setNativeLibPaths();
    await Obfuscate.setAllMaps();
    TagManager.loadAllTags();
  });

  group('AES Key Enforcement & Fail-Closed Guards', () {
    const validTestKey = '01234567890123456789012345678901';

    test(
      'handleEncrypt throws MissingKeyException when no key is supplied',
      () async {
        final ih = InputHandler();
        final qrypt = Qrypt.withTag(
          text: 'Secret payload without key',
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.en2,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: true,
        );

        expect(
          () => ih.handleEncrypt(qrypt),
          throwsA(isA<MissingKeyException>()),
        );
      },
    );

    test(
      'handleEncrypt throws MissingKeyException when customKey is empty string',
      () async {
        final ih = InputHandler();
        final qrypt = Qrypt.withTag(
          text: 'Secret payload with empty key',
          encryption: EncryptionMethod.aesCbc,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: false,
        );
        qrypt.customKey = '';
        qrypt.useCustomKey = true;

        expect(
          () => ih.handleEncrypt(qrypt),
          throwsA(isA<MissingKeyException>()),
        );
      },
    );

    test(
      'handleEncrypt succeeds when a valid custom key is provided',
      () async {
        final ih = InputHandler();
        final qrypt = Qrypt.withTag(
          text: 'Secret payload with valid key',
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: false,
        );
        qrypt.customKey = validTestKey;
        qrypt.useCustomKey = true;

        final result = await ih.handleEncrypt(qrypt);
        expect(result.text, isNotEmpty);
        expect(result.text, isNot(equals('Secret payload with valid key')));
        expect(result.text.contains(':'), isTrue);
      },
    );

    test(
      'handleDecrypt trial-decrypts AES-GCM ciphertext against saved keys',
      () async {
        final ih = InputHandler();
        const storage = AesKeyStorageService();
        await storage.clearAllKeys();

        final key1 = AESKey(
          id: 'wrong-key-id',
          name: 'Wrong Key',
          key: 'WrongKey000000000000000000000001',
          createdAt: DateTime.now(),
        );
        final key2 = AESKey(
          id: 'correct-key-id',
          name: 'Correct Key',
          key: validTestKey,
          createdAt: DateTime.now(),
        );
        await storage.saveKey(key1);
        await storage.saveKey(key2);
        await storage.setLastUsedKeyId('correct-key-id');

        // Encrypt with key2
        final qEncrypt = Qrypt.withTag(
          text: 'Trial decryption test message',
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: false,
        );
        qEncrypt.customKey = validTestKey;
        qEncrypt.useCustomKey = true;
        final comp = ih.handleCompression(qEncrypt);
        final enc = await ih.handleEncrypt(comp);

        // Decrypt without specifying customKey in headless context
        final qDecrypt = Qrypt(
          text: enc.text,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
        );

        final dec = await ih.handleDecrypt(qDecrypt);
        final result = ih.handleDeCompression(dec);
        expect(result.text, equals('Trial decryption test message'));
        expect(dec.customKey, equals(validTestKey));
      },
    );

    test(
      'handleDecrypt falls through to trial-decryption when pre-selected GCM key is wrong',
      () async {
        final ih = InputHandler();
        const storage = AesKeyStorageService();
        await storage.clearAllKeys();

        // Save correct key
        final correctKey = AESKey(
          id: 'correct-key-id',
          name: 'Correct Saved Key',
          key: validTestKey,
          createdAt: DateTime.now(),
        );
        await storage.saveKey(correctKey);

        // Encrypt with correct key
        final qEncrypt = Qrypt.withTag(
          text: 'Message encrypted with correct key',
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: false,
        );
        qEncrypt.customKey = validTestKey;
        qEncrypt.useCustomKey = true;
        final comp = ih.handleCompression(qEncrypt);
        final enc = await ih.handleEncrypt(comp);

        // Supply an incorrect pre-selected key
        final qDecrypt = Qrypt(
          text: enc.text,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
        );
        qDecrypt.customKey = 'WrongKey000000000000000000000002';
        qDecrypt.useCustomKey = true;

        // Instead of dead-ending, GCM auth failure falls through to trial-decryption
        final dec = await ih.handleDecrypt(qDecrypt);
        final result = ih.handleDeCompression(dec);
        expect(result.text, equals('Message encrypted with correct key'));
        expect(dec.customKey, equals(validTestKey));
      },
    );

    test(
      'handleDecrypt throws MissingKeyException in headless mode when trial decryption fails',
      () async {
        final ih = InputHandler();
        const storage = AesKeyStorageService();
        await storage.clearAllKeys();

        // Encrypt with valid key
        final qEncrypt = Qrypt.withTag(
          text: 'Unmatched key message',
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: false,
        );
        qEncrypt.customKey = validTestKey;
        qEncrypt.useCustomKey = true;
        final comp = ih.handleCompression(qEncrypt);
        final enc = await ih.handleEncrypt(comp);

        // Decrypt with no saved keys and headless context
        final qDecrypt = Qrypt(
          text: enc.text,
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
        );

        expect(
          () => ih.handleDecrypt(qDecrypt),
          throwsA(isA<MissingKeyException>()),
        );
      },
    );
  });
}
