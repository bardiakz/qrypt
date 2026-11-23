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
        maxBytes: 141,
        actualBytes: 250,
      );

      expect(exception.maxBytes, equals(141));
      expect(exception.actualBytes, equals(250));
      expect(
        exception.toString(),
        equals(
          'RSA-OAEP-256 can encrypt at most 141 bytes '
          '(your data compressed to 250 bytes). '
          'Use AES-GCM for larger payloads.',
        ),
      );
    });
  });

  group('RSA Payload Size Guard in InputHandler', () {
    test(
      'allows payloads up to exact Base64-adjusted maxBytes for 2048-bit key (141 bytes) and round-trips',
      () async {
        // 2048-bit OAEP-SHA256 max raw bytes = 190; Base64(141 bytes) = 188 bytes <= 190
        final boundaryText = 'A' * 141;
        final qrypt = Qrypt.withRSA(
          text: boundaryText,
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

        final decryptQrypt = Qrypt.withRSA(
          text: processed.text,
          encryption: EncryptionMethod.rsa,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: false,
          rsaKeyPair: rsa2048KeyPair,
          rsaReceiverPublicKey: rsa2048KeyPair.publicKey,
        );
        final decrypted = await ih.handleDeProcess(null, decryptQrypt, false);
        expect(decrypted.text, equals(boundaryText));
      },
    );

    test(
      'throws RsaPayloadTooLargeException for 2048-bit key at 142 bytes (Base64 = 192 > 190)',
      () async {
        final overBoundaryText = 'B' * 142;
        final qrypt = Qrypt.withRSA(
          text: overBoundaryText,
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
          expect(e.maxBytes, equals(141)); // ((2048 ~/ 8) - 66) ~/ 4 * 3 = 141
          expect(e.actualBytes, equals(142));
          expect(
            e.toString(),
            contains('RSA-OAEP-256 can encrypt at most 141 bytes'),
          );
          expect(e.toString(), contains('Use AES-GCM for larger payloads.'));
        }
      },
    );

    test(
      'allows exact 237-byte boundary and rejects 238 bytes for 3072-bit key',
      () async {
        // 3072-bit OAEP-SHA256 max raw bytes = 318; Base64(237) = 316 <= 318
        final okText = 'C' * 237;
        final okQrypt = Qrypt.withRSA(
          text: okText,
          encryption: EncryptionMethod.rsa,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: false,
          rsaKeyPair: rsa3072KeyPair,
          rsaReceiverPublicKey: rsa3072KeyPair.publicKey,
        );
        final okProcessed = await ih.handleProcess(okQrypt);
        expect(okProcessed.text, isNotEmpty);

        // 238 bytes -> Base64 = 320 > 318
        final largeText = 'C' * 238;
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
          expect(e.maxBytes, equals(237)); // ((3072 ~/ 8) - 66) ~/ 4 * 3 = 237
          expect(e.actualBytes, equals(238));
          expect(
            e.toString(),
            contains('RSA-OAEP-256 can encrypt at most 237 bytes'),
          );
          expect(e.toString(), contains('Use AES-GCM for larger payloads.'));
        }
      },
    );

    test('checks size AFTER compression (qrypt.compressedText)', () async {
      // Highly compressible text: 1400 characters that compress to <= 237 bytes with gzip
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

      // With gzip, 1400 repeating chars compress to ~40-50 bytes <= 237 bytes
      final processed = await ih.handleProcess(qrypt);
      expect(processed.compressedText.length, lessThanOrEqualTo(237));
      expect(processed.text, isNotEmpty);
    });
  });
}
