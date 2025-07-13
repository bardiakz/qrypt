abstract class Encryption {
  String get tag;
}

enum EncryptionMethod {
  none,
  aesCbc,
}
extension EncryptionMethodName on EncryptionMethod {
  String get displayName {
    switch (this) {
      case EncryptionMethod.none:
        return 'NONE';
      case EncryptionMethod.aesCbc:
        return 'AES-CBC';
      // case Cipher.AES_GCM:
      //   return 'AES-GCM';

    }
  }
}
