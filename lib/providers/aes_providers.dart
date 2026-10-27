import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/providers/simple_state_provider.dart';
import '../services/aes/aes_key_storage_service.dart';

final aesKeyStorageServiceProvider = Provider<AesKeyStorageService>(
  (ref) => const AesKeyStorageService(),
);

final aesKeysProvider = FutureProvider<List<AESKey>>((ref) async {
  final service = ref.read(aesKeyStorageServiceProvider);
  return await service.getKeys();
});

final selectedAESEncryptKeyProvider = simpleStateProvider<AESKey?>(null);
final selectedAESDecryptKeyProvider = simpleStateProvider<AESKey?>(null);
