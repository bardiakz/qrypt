abstract class Encryption {
  String get tag;
}

enum EncryptionMethod { none, aesCbc, aesCtr, aesGcm, rsa }

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
        return 'RSA';
    }
  }
}
