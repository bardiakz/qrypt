import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Crypto {
  static String generateSHA224Hash(String input) {
    final secretKey =
        dotenv.env['HASH_SECRET'] ??
        '933b5a33bdf532c9b9aad4efd26c2263'; //if key isnt loaded it uses the default secret
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
