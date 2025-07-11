import 'package:flutter_riverpod/flutter_riverpod.dart';

final defaultEncryptionProvider = StateProvider<bool>((ref) => true);

final autoDetectTagProvider = StateProvider<bool>((ref) => true);

// Advanced settings
final selectedEncryptionProvider = StateProvider<String>((ref) => 'Kyber');
final selectedObfuscationProvider = StateProvider<String>((ref) => 'None');
final publicKeyProvider = StateProvider<String>((ref) => '');
