import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/providers/simple_state_provider.dart';

import '../models/Qrypt.dart';
import '../models/compression_method.dart';
import '../models/sign_method.dart';

final defaultEncryptionProvider = simpleStateProvider<bool>(true);
final useTagProvider = simpleStateProvider<bool>(true);

final autoDetectTagProvider = simpleStateProvider<bool>(true);
final inputTextProvider = simpleStateProvider<String>('');
final isProcessingProvider = simpleStateProvider<bool>(false);

// Advanced settings
final publicKeyRequiredProvider = simpleStateProvider<bool>(false);
final selectedEncryptionProvider =
    simpleStateProvider<EncryptionMethod>(EncryptionMethod.none);
final selectedObfuscationProvider =
    simpleStateProvider<ObfuscationMethod>(ObfuscationMethod.none);
final selectedCompressionProvider =
    simpleStateProvider<CompressionMethod>(CompressionMethod.gZip);
final selectedSignProvider = simpleStateProvider<SignMethod>(SignMethod.none);
final publicKeyProvider = simpleStateProvider<String>('');
final inputQryptProvider = simpleStateProvider<Qrypt>(
  Qrypt(
    text: '',
    encryption: EncryptionMethod.aesGcm,
    obfuscation: ObfuscationMethod.en2,
    compression: CompressionMethod.gZip,
    sign: SignMethod.none,
  ),
);
final processedEncryptProvider = simpleStateProvider<Qrypt>(
  Qrypt(
    text: '',
    encryption: EncryptionMethod.aesGcm,
    obfuscation: ObfuscationMethod.en2,
    compression: CompressionMethod.gZip,
    sign: SignMethod.none,
  ),
);
final processedDecryptProvider = simpleStateProvider<Qrypt>(
  Qrypt(
    text: '',
    encryption: EncryptionMethod.aesGcm,
    obfuscation: ObfuscationMethod.en2,
    compression: CompressionMethod.gZip,
    sign: SignMethod.none,
  ),
);

final customEncryptAesKeyProvider = simpleStateProvider<String>('');
final useCustomEncryptAesKeyProvider = simpleStateProvider<bool>(false);
final customDecryptAesKeyProvider = simpleStateProvider<String>('');
final useCustomDecryptAesKeyProvider = simpleStateProvider<bool>(false);

final isMLKemModeProvider = Provider<bool>((ref) {
  return ref.watch(selectedEncryptionProvider) == EncryptionMethod.mlKem;
});
