import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';

import '../services/ml_dsa/ml_dsa_key_service.dart';

final mlDsaKeyServiceProvider = Provider((ref) => MlDsaKeyService());

final mlDsaKeyPairsProvider = FutureProvider<List<QryptMLDSAKeyPair>>((
  ref,
) async {
  final service = ref.read(mlDsaKeyServiceProvider);
  return await service.getKeyPairs();
});

final selectedMlDsaSignKeyPairProvider = StateProvider<QryptMLDSAKeyPair?>(
  (ref) => null,
);
final selectedMlDsaVerifyKeyPairProvider = StateProvider<QryptMLDSAKeyPair?>(
  (ref) => null,
);
final verifyMlDsaPublicKeyProvider = StateProvider<String>((ref) => '');
final signMlDsaPublicKeyProvider = StateProvider<String>((ref) => '');
String verifyMlDsaPublicKeyGlobal = '';
