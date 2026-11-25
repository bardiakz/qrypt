abstract class Encryption {
  String get tag;
}

enum EncryptionMethod { none, aesCbc, aesCtr, aesGcm, rsa, rsaSign, mlKem }

extension EncryptionMethodName on EncryptionMethod {
  String get displayName {
    switch (this) {
      case EncryptionMethod.none:
        return 'NONE';
      case EncryptionMethod.aesCbc:
        return 'AES-CBC';
      case EncryptionMethod.aesCtr:
        return 'AES-CTR';
      case EncryptionMethod.aesGcm:
        return 'AES-GCM';
      case EncryptionMethod.rsa:
        return 'RSA-OAEP-256';
      case EncryptionMethod.rsaSign:
        return 'RSA-PSS256-OAEP1 (with sign)';
      case EncryptionMethod.mlKem:
        return 'ML-KEM (Kyber)';
    }
  }
}

extension EncryptionMethodHelpers on EncryptionMethod {
  /// Whether this method should be shown in the UI encryption picker.
  /// [rsaSign] is a legacy combined mode kept only for backward-compatible decode.
  bool get isUserSelectable => this != EncryptionMethod.rsaSign;
}
