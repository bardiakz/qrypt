import 'dart:ffi';
import 'package:qrypt/oqs_bindings.dart'; // this contains OQS_KEM_kyber_512_new

void main() {
  // Load the DLL
  final dylib = DynamicLibrary.open('liboqs/oqs.dll');

  final kem = OQS_KEM_kyber_512_new(); // returns Pointer<OQS_KEM>

  print('Public key length: ${kem.ref.length_public_key}');

  // Clean up
  OQS_KEM_free(kem);
}
