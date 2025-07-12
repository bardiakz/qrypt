import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/encryption.dart';
import 'package:qrypt/models/obfuscation.dart';

import '../models/Qrypt.dart';

final defaultEncryptionProvider = StateProvider<bool>((ref) => true);
final useTagProvider = StateProvider<bool>((ref) => true);

final autoDetectTagProvider = StateProvider<bool>((ref) => true);

// Advanced settings
final selectedEncryptionProvider = StateProvider<EncryptionMethod>((ref) => EncryptionMethod.none);
final selectedObfuscationProvider = StateProvider<ObfuscationMethod>((ref) => ObfuscationMethod.none);
final publicKeyProvider = StateProvider<String>((ref) => '');
final inputQryptProvider = StateProvider<Qrypt>((ref) => Qrypt(text: '', encryption: EncryptionMethod.none, obfuscation: ObfuscationMethod.none));
final processedCryptProvider = StateProvider<Qrypt>((ref) => Qrypt(text: 'defNotProcessed', encryption: EncryptionMethod.none, obfuscation: ObfuscationMethod.none));

