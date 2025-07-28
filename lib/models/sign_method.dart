enum SignMethod { none, mlDsa }

extension SignMethodMethodName on SignMethod {
  String get displayName {
    switch (this) {
      case SignMethod.none:
        return 'NONE';
      case SignMethod.mlDsa:
        return 'ML-DSA (Dilithium)';
    }
  }
}
