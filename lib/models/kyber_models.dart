// ML-KEM Key Sizes enum
enum MLKemKeySize {
  kem512(512, "ML-KEM-512"),
  kem768(768, "ML-KEM-768"),
  kem1024(1024, "ML-KEM-1024");

  const MLKemKeySize(this.bits, this.displayName);

  final int bits;
  final String displayName;
}

extension MLKemKeySizeExtension on MLKemKeySize {
  /// Detects ML-KEM key size from public key byte length.
  /// ML-KEM-512: 800 bytes, ML-KEM-768: 1184 bytes, ML-KEM-1024: 1568 bytes.
  static MLKemKeySize? fromPublicKeyLength(int length) {
    switch (length) {
      case 800:
        return MLKemKeySize.kem512;
      case 1184:
        return MLKemKeySize.kem768;
      case 1568:
        return MLKemKeySize.kem1024;
      default:
        return null;
    }
  }

  /// Detects ML-KEM key size from secret key byte length.
  /// ML-KEM-512: 1632 bytes, ML-KEM-768: 2400 bytes, ML-KEM-1024: 3168 bytes.
  static MLKemKeySize? fromSecretKeyLength(int length) {
    switch (length) {
      case 1632:
        return MLKemKeySize.kem512;
      case 2400:
        return MLKemKeySize.kem768;
      case 3168:
        return MLKemKeySize.kem1024;
      default:
        return null;
    }
  }

  /// Detects ML-KEM key size from ciphertext byte length.
  /// ML-KEM-512: 768 bytes, ML-KEM-768: 1088 bytes, ML-KEM-1024: 1568 bytes.
  static MLKemKeySize? fromCiphertextLength(int length) {
    switch (length) {
      case 768:
        return MLKemKeySize.kem512;
      case 1088:
        return MLKemKeySize.kem768;
      case 1568:
        return MLKemKeySize.kem1024;
      default:
        return null;
    }
  }

  /// Detects from algorithm string name (case-insensitive).
  static MLKemKeySize fromAlgorithmName(String? name) {
    if (name == null) return MLKemKeySize.kem768;
    final normalized = name.toUpperCase().replaceAll('_', '-');
    if (normalized.contains('512')) return MLKemKeySize.kem512;
    if (normalized.contains('1024')) return MLKemKeySize.kem1024;
    return MLKemKeySize.kem768;
  }
}
