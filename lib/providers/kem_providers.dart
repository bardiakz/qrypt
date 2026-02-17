import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/providers/simple_state_provider.dart';

import '../services/kem/kem_service.dart';

final kemKeyServiceProvider = Provider((ref) => KemKeyService());

final kemKeyPairsProvider = FutureProvider<List<QryptKEMKeyPair>>((ref) async {
  final service = ref.read(kemKeyServiceProvider);
  return await service.getKeyPairs();
});

final selectedKemEncryptKeyPairProvider =
    simpleStateProvider<QryptKEMKeyPair?>(null);
final selectedKemDecryptKeyPairProvider =
    simpleStateProvider<QryptKEMKeyPair?>(null);
final receiverKemPublicKeyProvider = simpleStateProvider<String>('');
final decryptKemPublicKeyProvider = simpleStateProvider<String>('');
String decryptKemPublicKeyGlobal = '';
