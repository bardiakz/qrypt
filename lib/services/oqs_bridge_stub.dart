import 'dart:typed_data';

const String _kWebUnsupportedMessage =
    'Post-quantum ML-KEM / ML-DSA require native liboqs binaries and are not available on Flutter Web. Use AES or RSA in web preview, or run Qrypt on Android, iOS, Linux, macOS, or Windows.';

class KEMKeyPair {
  final Uint8List publicKey;
  final Uint8List secretKey;

  const KEMKeyPair({required this.publicKey, required this.secretKey});
}

class KEMEncapsulationResult {
  final Uint8List ciphertext;
  final Uint8List sharedSecret;

  const KEMEncapsulationResult({
    required this.ciphertext,
    required this.sharedSecret,
  });
}

class KEM {
  final String algorithmName;

  KEM._(this.algorithmName);

  static KEM? create(String algorithmName) => KEM._(algorithmName);

  KEMKeyPair generateKeyPair() {
    throw UnsupportedError(_kWebUnsupportedMessage);
  }

  KEMEncapsulationResult encapsulate(Uint8List publicKey) {
    throw UnsupportedError(_kWebUnsupportedMessage);
  }

  Uint8List decapsulate(Uint8List ciphertext, Uint8List secretKey) {
    throw UnsupportedError(_kWebUnsupportedMessage);
  }

  void dispose() {}
}

class SignatureKeyPair {
  final Uint8List publicKey;
  final Uint8List secretKey;

  const SignatureKeyPair({required this.publicKey, required this.secretKey});
}

class Signature {
  final String algorithmName;

  Signature._(this.algorithmName);

  static Signature? create(String algorithmName) => Signature._(algorithmName);

  static List<String> getSupportedSignatureAlgorithms() => const <String>[];

  int get publicKeyLength => 0;
  int get secretKeyLength => 0;
  int get maxSignatureLength => 0;

  SignatureKeyPair generateKeyPair() {
    throw UnsupportedError(_kWebUnsupportedMessage);
  }

  Uint8List sign(Uint8List message, Uint8List secretKey) {
    throw UnsupportedError(_kWebUnsupportedMessage);
  }

  bool verify(Uint8List message, Uint8List signature, Uint8List publicKey) {
    throw UnsupportedError(_kWebUnsupportedMessage);
  }

  void dispose() {}
}
