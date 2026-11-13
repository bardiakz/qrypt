enum SignMethod { none, rsaPss, mlDsa }

extension SignMethodMethodName on SignMethod {
  String get displayName {
    switch (this) {
      case SignMethod.none:
        return 'NONE';
      case SignMethod.rsaPss:
        return 'RSA-PSS (SHA-256)';
      case SignMethod.mlDsa:
        return 'ML-DSA (Dilithium)';
    }
  }
}
