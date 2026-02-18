import 'dart:convert';
import 'package:crypto/crypto.dart';

class Crypto {
  // This key only namespaces internal tag IDs (method metadata prefix), and is only kept due to backward compatibility
  // not used for user secrets or ciphertext encryption.
  static const String _tagHashSecret = 'c6277aa66f020fbb83f8b307f3b43adc';

  static String generateSHA224Hash(String input) {
    final secretKey = _tagHashSecret;
    // String secretKey = 'faf';
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(input);

    final hmacSha224 = Hmac(sha224, key);
    final digest = hmacSha224.convert(bytes);

    return digest.toString();
  }

  static String generateTagHash(String tag) {
    final String hash = generateSHA224Hash(tag);
    return hash.substring(2, 8);
  }
}

// void main() async {
//   String a = Crypto.generateSHA224Hash('qmsa_01_02');
//   print(a.substring(0, 6));
// }
