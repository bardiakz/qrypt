import 'dart:convert';
import 'dart:typed_data';

import 'package:oqs/oqs.dart';

void main() {
  final kem = KEM.create('ML-KEM-768');
  if (kem == null) {
    print('Algorithm not supported');
    return;
  }
  try {
    // Generate a key pair
    final KEMKeyPair keyPair = kem.generateKeyPair();
    print('Public key length: ${keyPair.publicKey.length}');
    print('Secret key length: ${keyPair.secretKey.length}');

    print('Public key : ${base64Encode(keyPair.publicKey)}');
    print('Secret key : ${base64Encode(keyPair.secretKey)}');

    // Encapsulate a shared secret
    final encapsulationResult = kem.encapsulate(keyPair.publicKey);
    print('Ciphertext length: ${encapsulationResult.ciphertext.length}');
    print('Shared secret length: ${encapsulationResult.sharedSecret.length}');

    // Decapsulate the shared secret
    final decapsulatedSecret = kem.decapsulate(
      encapsulationResult.ciphertext,
      keyPair.secretKey,
    );

    // Verify the shared secrets match
    print(
      'Secrets match: ${_listsEqual(encapsulationResult.sharedSecret, decapsulatedSecret)}',
    );
  } finally {
    // Clean up KEM instance
    kem.dispose();
  }
}

bool _listsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
