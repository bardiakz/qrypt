abstract class Obfuscation {
  String get tag;
}

enum ObfuscationMethod {
  none,
  en1,
  en2,
  fa1,
  fa2,
  b64,
  rot13,
  xor,
  // reverse,
}

extension ObfuscationMethodName on ObfuscationMethod {
  String get displayName {
    switch (this) {
      case ObfuscationMethod.none:
        return 'NONE';
      case ObfuscationMethod.en1:
        return 'EN1 (Character-based)';
      case ObfuscationMethod.en2:
        return 'EN2 (Word-based)';
      case ObfuscationMethod.fa1:
        return 'FA1 (Character-based)';
      case ObfuscationMethod.fa2:
        return 'FA2 (Word-based)';
      case ObfuscationMethod.b64:
        return 'Base64';
      case ObfuscationMethod.rot13:
        return 'ROT13';
      case ObfuscationMethod.xor:
        return 'XOR';
      // case ObfuscationMethod.reverse:
      //   return 'Reverse';
    }
  }

  String get methodType {
    switch (this) {
      case ObfuscationMethod.none:
        return 'None';
      case ObfuscationMethod.en1:
      case ObfuscationMethod.fa1:
        return 'Character-based';
      case ObfuscationMethod.en2:
      case ObfuscationMethod.fa2:
        return 'Word-based';
      case ObfuscationMethod.b64:
        return 'Encoding';
      case ObfuscationMethod.rot13:
        return 'Caesar Cipher';
      case ObfuscationMethod.xor:
        return 'Bitwise';
      // case ObfuscationMethod.reverse:
      //   return 'String Manipulation';
    }
  }

  String get languageInfo {
    switch (this) {
      case ObfuscationMethod.en1:
      case ObfuscationMethod.en2:
        return 'English';
      case ObfuscationMethod.fa1:
      case ObfuscationMethod.fa2:
        return 'Farsi/Persian';
      case ObfuscationMethod.none:
      case ObfuscationMethod.b64:
      case ObfuscationMethod.rot13:
      case ObfuscationMethod.xor:
        return 'Language Independent';
      // case ObfuscationMethod.reverse:
      //   return 'Language Independent';
    }
  }

  // Helper to get short name for UI
}

extension ObfuscationMethodDetails on ObfuscationMethod {
  String get detailedDescription {
    switch (this) {
      case ObfuscationMethod.none:
        return 'No obfuscation applied';
      case ObfuscationMethod.en1:
        return 'English character-based substitution cipher';
      case ObfuscationMethod.en2:
        return 'English word-based substitution cipher';
      case ObfuscationMethod.fa1:
        return 'Farsi/Persian character-based substitution cipher';
      case ObfuscationMethod.fa2:
        return 'Farsi/Persian word-based substitution cipher';
      case ObfuscationMethod.b64:
        return 'Base64 encoding obfuscation';
      case ObfuscationMethod.rot13:
        return 'ROT13 Caesar cipher (13-position alphabet shift)';
      case ObfuscationMethod.xor:
        return 'XOR bitwise obfuscation with fixed key';
      // case ObfuscationMethod.reverse:
      //   return 'String reversal obfuscation';
    }
  }
}
