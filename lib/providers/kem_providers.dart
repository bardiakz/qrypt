import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/kem_key_pair.dart';

import '../services/kem/kem_service.dart';

final kemKeyServiceProvider = Provider((ref) => KemKeyService());

final kemKeyPairsProvider = FutureProvider<List<QryptKEMKeyPair>>((ref) async {
  final service = ref.read(kemKeyServiceProvider);
  return await service.getKeyPairs();
});

final selectedKemEncryptKeyPairProvider = StateProvider<QryptKEMKeyPair?>(
  (ref) => null,
);
final selectedKemDecryptKeyPairProvider = StateProvider<QryptKEMKeyPair?>(
  (ref) => null,
);
final receiverKemPublicKeyProvider = StateProvider<String>((ref) => '');
final decryptKemPublicKeyProvider = StateProvider<String>((ref) => '');
String decryptKemPublicKeyGlobal = '';
