import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/exceptions.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final InputHandler ih;
  late final RSAKeyService rsaService;
  late final RSAKeyPair rsa2048KeyPair;
  late final RSAKeyPair rsa3072KeyPair;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    Compression.setNativeLibPaths();
    TagManager.loadAllTags();

    ih = InputHandler();
    rsaService = RSAKeyService();

    rsa2048KeyPair = await rsaService.generateKeyPair(
      'Guard-2048',
      keySize: 2048,
    );

    rsa3072KeyPair = await rsaService.generateKeyPair(
      'Guard-3072',
      keySize: 3072,
    );
  });

  group('RsaPayloadTooLargeException', () {
    test('formats error message with byte counts and AES-GCM recommendation', () {
      const exception = RsaPayloadTooLargeException(
        maxBytes: 190,
        actualBytes: 250,
      );

      expect(exception.maxBytes, equals(190));
      expect(exception.actualBytes, equals(250));
      expect(
        exception.toString(),
        equals(
          'RSA-OAEP-256 can encrypt at most 190 bytes '
          '(your data compressed to 250 bytes). '
          'Use AES-GCM for larger payloads.',
        ),
      );
    });
  });

  group('RSA Payload Size Guard in InputHandler', () {
    test('allows payloads within maxBytes for 2048-bit key (<= 190 bytes)', () async {
      // 50 bytes of plaintext with compression none = 50 compressed bytes <= 190
      final smallText = 'A' * 50;
      final qrypt = Qrypt.withRSA(
        text: smallText,
        encryption: EncryptionMethod.rsa,
        obfuscation: ObfuscationMethod.none,
        compression: CompressionMethod.none,
        sign: SignMethod.none,
        useTag: false,
        rsaKeyPair: rsa2048KeyPair,
        rsaReceiverPublicKey: rsa2048KeyPair.publicKey,
      );

      final processed = await ih.handleProcess(qrypt);
      expect(processed.text, isNotEmpty);
    });

    test('throws RsaPayloadTooLargeException for 2048-bit key when compressed text > 190 bytes', () async {
      // 250 bytes of plaintext with compression none = 250 compressed bytes > 190
      final largeText = 'B' * 250;
      final qrypt = Qrypt.withRSA(
        text: largeText,
        encryption: EncryptionMethod.rsa,
        obfuscation: ObfuscationMethod.none,
        compression: CompressionMethod.none,
        sign: SignMethod.none,
        useTag: false,
        rsaKeyPair: rsa2048KeyPair,
        rsaReceiverPublicKey: rsa2048KeyPair.publicKey,
      );

      try {
        await ih.handleProcess(qrypt);
        fail('Expected RsaPayloadTooLargeException to be thrown');
      } on RsaPayloadTooLargeException catch (e) {
        expect(e.maxBytes, equals(190)); // (2048 / 8) - 66 = 190
        expect(e.actualBytes, equals(250));
        expect(e.toString(), contains('RSA-OAEP-256 can encrypt at most 190 bytes'));
        expect(e.toString(), contains('Use AES-GCM for larger payloads.'));
      }
    });

    test('calculates correct maxBytes for 3072-bit key (318 bytes)', () async {
      // 350 bytes with compression none = 350 compressed bytes > 318
      final largeText = 'C' * 350;
      final qrypt = Qrypt.withRSA(
        text: largeText,
        encryption: EncryptionMethod.rsa,
        obfuscation: ObfuscationMethod.none,
        compression: CompressionMethod.none,
        sign: SignMethod.none,
        useTag: false,
        rsaKeyPair: rsa3072KeyPair,
        rsaReceiverPublicKey: rsa3072KeyPair.publicKey,
      );

      try {
        await ih.handleProcess(qrypt);
        fail('Expected RsaPayloadTooLargeException to be thrown');
      } on RsaPayloadTooLargeException catch (e) {
        expect(e.maxBytes, equals(318)); // (3072 / 8) - 66 = 318
        expect(e.actualBytes, equals(350));
        expect(e.toString(), contains('RSA-OAEP-256 can encrypt at most 318 bytes'));
        expect(e.toString(), contains('Use AES-GCM for larger payloads.'));
      }
    });

    test('checks size AFTER compression (qrypt.compressedText)', () async {
      // Highly compressible text: 1400 characters that compress to < 190 bytes with gzip
      final compressibleText = 'Repeat ' * 200; // 1400 chars
      final qrypt = Qrypt.withRSA(
        text: compressibleText,
        encryption: EncryptionMethod.rsa,
        obfuscation: ObfuscationMethod.none,
        compression: CompressionMethod.gZip,
        sign: SignMethod.none,
        useTag: false,
        rsaKeyPair: rsa3072KeyPair,
        rsaReceiverPublicKey: rsa3072KeyPair.publicKey,
      );

      // With gzip, 1400 repeating chars compress to ~40-50 bytes <= 318 bytes
      final processed = await ih.handleProcess(qrypt);
      expect(processed.compressedText.length, lessThanOrEqualTo(318));
      expect(processed.text, isNotEmpty);
    });
  });
}
