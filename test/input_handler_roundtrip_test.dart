import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/resources/obfuscation/built_in_obfuscation_maps.dart';
import 'package:qrypt/resources/obfuscation/built_in_v2_maps.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  ObfuscationService.rebuildWith({
    ObfuscationMethod.en1: builtInEn1Map,
    ObfuscationMethod.en2: builtInEn2Map,
    ObfuscationMethod.fa1: builtInFa1Map,
    ObfuscationMethod.fa2: builtInFa2Map,
    for (final m in ObfuscationMethod.values)
      if (m.isV2Mapped) m: builtInV2MapForMethod(m),
  });
  TagManager.initializeTags();

  final ih = InputHandler();
  const testAesKey = '0123456789abcdef0123456789abcdef'; // 32-character AES key

  final plaintexts = <String, String>{
    'ASCII': 'Hello, World! Testing Qrypt input handler symmetric pipeline.',
    'Persian': 'این یک پیام آزمایشی به زبان فارسی برای سنجش سیستم رمزنگاری است.',
    'Emoji': '🚀🔐🛡️✨🎉',
    '2KB string': 'The quick brown fox jumps over the lazy dog. 1234567890! ' * 36,
  };

  final compressions = [
    CompressionMethod.none,
    CompressionMethod.gZip,
  ];

  final encryptions = [
    EncryptionMethod.none,
    EncryptionMethod.aesCbc,
    EncryptionMethod.aesCtr,
    EncryptionMethod.aesGcm,
  ];

  final obfuscations = ObfuscationMethod.values
      .where((m) => ObfuscationService.isAvailable(m))
      .toList();

  group('InputHandler roundtrip matrix tests (Phase 4b)', () {
    for (final comp in compressions) {
      for (final enc in encryptions) {
        for (final obf in obfuscations) {
          final isAes = enc != EncryptionMethod.none;

          test('Roundtrip: ${comp.name} + ${enc.name} + ${obf.name}', () async {
            for (final entry in plaintexts.entries) {
              final label = entry.key;
              final sample = entry.value;

              // 1. Configure and process encrypt
              final inputQ = Qrypt.withTag(
                text: sample,
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

              final processed = await ih.handleProcess(inputQ);
              final taggedPayload = processed.text;

              expect(taggedPayload, isNotEmpty, reason: '$label: payload is empty');

              // 2. Configure and process decrypt
              final decryptQ = Qrypt.autoDecrypt(text: taggedPayload);
              if (isAes) {
                decryptQ.customKey = testAesKey;
                decryptQ.useCustomKey = true;
              }

              final recovered = await ih.handleDeProcess(null, decryptQ, true);

              // 3. Assert plaintext round-trip recovery
              expect(
                recovered.text,
                equals(sample),
                reason:
                    'Failed roundtrip for $label on ${comp.name} + ${enc.name} + ${obf.name}',
              );
            }
          });
        }
      }
    }
  });
}
