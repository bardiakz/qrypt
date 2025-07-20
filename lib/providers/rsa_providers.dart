import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rsa_key_pair.dart';
import '../services/rsa/rsa_key_service.dart';

final rsaKeyServiceProvider = Provider((ref) => RSAKeyService());

final rsaKeyPairsProvider = FutureProvider<List<RSAKeyPair>>((ref) async {
  final service = ref.read(rsaKeyServiceProvider);
  return await service.getKeyPairs();
});

final selectedRSAEncryptKeyPairProvider = StateProvider<RSAKeyPair?>(
  (ref) => null,
);
final selectedRSADecryptKeyPairProvider = StateProvider<RSAKeyPair?>(
  (ref) => null,
);
final senderPublicKeyProvider = StateProvider<String>((ref) => '');
