import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
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
  late final RSAKeyPair rsaKeyPair;
  const testAesKey = '0123456789abcdef0123456789abcdef'; // 32-byte (256-bit) test key
  const samplePlaintext =
      'Hello Qrypt World! پیام محرمانه فارسی با اعداد 123456 و نمادها: !@#%^&*()';
  const shortRsaPlaintext = 'Qrypt RSA test msg 123 پیام';

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    Compression.setNativeLibPaths();
    TagManager.loadAllTags();
    ih = InputHandler();

    final rsaService = RSAKeyService();
    rsaKeyPair = await rsaService.generateKeyPair('Matrix Test RSA Key');
  });

  group('Full Matrix Symmetric Pipeline Roundtrip Tests (160 Combinations)', () {
    final symmetricEncryptions = [
      EncryptionMethod.none,
      EncryptionMethod.aesGcm,
      EncryptionMethod.aesCbc,
      EncryptionMethod.aesCtr,
    ];

    for (final enc in symmetricEncryptions) {
      for (final comp in CompressionMethod.values) {
        for (final obf in ObfuscationMethod.values.where((m) => m != ObfuscationMethod.custom)) {
          test(
            'Roundtrip: ${comp.name} + ${enc.name} + ${obf.name} (tagged)',
            () async {
              final isAes = enc != EncryptionMethod.none;

              // 1. Configure and tag Qrypt model
              final inputQ = Qrypt.withTag(
                text: samplePlaintext,
                encryption: enc,
                obfuscation: obf,
                compression: comp,
                sign: SignMethod.none,
                useTag: true,
              );
              if (isAes) {
                inputQ.customKey = testAesKey;
                inputQ.useCustomKey = true;
              }

              // 2. Execute forward pipeline: compress -> encrypt -> tag -> obfuscate
              final processed = await ih.handleProcess(inputQ);
              final taggedPayload = processed.text;

              expect(taggedPayload, isNotEmpty);
              expect(taggedPayload, isNot(equals(samplePlaintext)));

              // 3. Configure reverse auto-decrypt model
              final decryptQ = Qrypt.autoDecrypt(text: taggedPayload);
              if (isAes) {
                decryptQ.customKey = testAesKey;
                decryptQ.useCustomKey = true;
              }

              // 4. Execute reverse pipeline: match tag -> deobfuscate -> decrypt -> decompress
              final recovered = await ih.handleDeProcess(null, decryptQ, true);

              // 5. Assert deterministic plaintext recovery
              expect(
                recovered.text,
                equals(samplePlaintext),
                reason:
                    'Failed to recover plaintext for combination: ${comp.name} + ${enc.name} + ${obf.name}',
              );
            },
          );
        }
      }
    }
  });

  group('Full Matrix RSA Pipeline Roundtrip Tests (40 Combinations)', () {
    for (final comp in CompressionMethod.values) {
      for (final obf in ObfuscationMethod.values.where((m) => m != ObfuscationMethod.custom)) {
        test(
          'Roundtrip: ${comp.name} + rsa + ${obf.name} (tagged)',
          () async {
            // 1. Configure and tag RSA Qrypt model
            final inputQ = Qrypt.withRSA(
              text: shortRsaPlaintext,
              encryption: EncryptionMethod.rsa,
              obfuscation: obf,
              compression: comp,
              sign: SignMethod.none,
              useTag: true,
              rsaKeyPair: rsaKeyPair,
              rsaReceiverPublicKey: rsaKeyPair.publicKey,
            );

            // 2. Execute forward pipeline
            final processed = await ih.handleProcess(inputQ);
            final taggedPayload = processed.text;

            expect(taggedPayload, isNotEmpty);
            expect(taggedPayload, isNot(equals(shortRsaPlaintext)));

            // 3. Configure reverse auto-decrypt model with recipient private key
            final decryptQ = Qrypt.autoDecrypt(text: taggedPayload);
            decryptQ.rsaKeyPair = rsaKeyPair;

            // 4. Execute reverse pipeline
            final recovered = await ih.handleDeProcess(null, decryptQ, true);

            // 5. Assert deterministic recovery
            expect(
              recovered.text,
              equals(shortRsaPlaintext),
              reason:
                  'Failed to recover RSA plaintext for combination: ${comp.name} + rsa + ${obf.name}',
            );
          },
        );
      }
    }
  });
}
