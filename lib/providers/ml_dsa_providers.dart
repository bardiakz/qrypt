import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import 'package:qrypt/providers/simple_state_provider.dart';

import '../services/ml_dsa/ml_dsa_key_service.dart';

final mlDsaKeyServiceProvider = Provider((ref) => MlDsaKeyService());

final mlDsaKeyPairsProvider = FutureProvider<List<QryptMLDSAKeyPair>>((
  ref,
) async {
  final service = ref.read(mlDsaKeyServiceProvider);
  return await service.getKeyPairs();
});

final selectedMlDsaSignKeyPairProvider =
    simpleStateProvider<QryptMLDSAKeyPair?>(null);
final selectedMlDsaVerifyKeyPairProvider =
    simpleStateProvider<QryptMLDSAKeyPair?>(null);
final verifyMlDsaPublicKeyProvider = simpleStateProvider<String>('');
final signMlDsaPublicKeyProvider = simpleStateProvider<String>('');
String verifyMlDsaPublicKeyGlobal = '';
