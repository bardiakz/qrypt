import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/providers/simple_state_provider.dart';

import '../models/rsa_key_pair.dart';
import '../services/rsa/rsa_key_service.dart';

final rsaKeyServiceProvider = Provider((ref) => RSAKeyService());

final rsaKeyPairsProvider = FutureProvider<List<RSAKeyPair>>((ref) async {
  final service = ref.read(rsaKeyServiceProvider);
  return await service.getKeyPairs();
});

final selectedRSAEncryptKeyPairProvider = simpleStateProvider<RSAKeyPair?>(
  null,
);
final selectedRSADecryptKeyPairProvider = simpleStateProvider<RSAKeyPair?>(
  null,
);
final rsaReceiverPublicKeyProvider = simpleStateProvider<String>('');
final rsaDecryptPublicKeyProvider = simpleStateProvider<String>('');
String decryptPublicKeyGlobal = '';
