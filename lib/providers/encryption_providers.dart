import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/services/compression.dart';

import '../models/Qrypt.dart';
import '../models/compression_method.dart';

final defaultEncryptionProvider = StateProvider<bool>((ref) => true);
final useTagProvider = StateProvider<bool>((ref) => true);

final autoDetectTagProvider = StateProvider<bool>((ref) => true);

// Advanced settings
final selectedEncryptionProvider = StateProvider<EncryptionMethod>((ref) => EncryptionMethod.none);
final selectedObfuscationProvider = StateProvider<ObfuscationMethod>((ref) => ObfuscationMethod.none);
final selectedCompressionProvider = StateProvider<CompressionMethod>((ref) => CompressionMethod.gZip);
final publicKeyProvider = StateProvider<String>((ref) => '');
final inputQryptProvider = StateProvider<Qrypt>((ref) => Qrypt(text: '', encryption: EncryptionMethod.none, obfuscation: ObfuscationMethod.none,compression: CompressionMethod.gZip));
final processedCryptProvider = StateProvider<Qrypt>((ref) => Qrypt(text: 'defNotProcessed', encryption: EncryptionMethod.none, obfuscation: ObfuscationMethod.none,compression: CompressionMethod.gZip));

