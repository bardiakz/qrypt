import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/encryption_method.dart';
import 'compression.dart';

class Aes extends Encryption {
  @override
  String get tag => 'aes';

  static final _key = encrypt.Key.fromUtf8(dotenv.env['ENCRYPTION_KEY']!);

  ///Encrypt AES-CBC
  static Map<String, String> encryptAesCbc(Uint8List compressed) {
    // final compressed = Compression.gZipCompress(utf8.encode(plaintext));
    final iv = encrypt.IV.fromLength(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encryptBytes(compressed, iv: iv);

    final hexEncrypted = encrypted.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('');
    final hexIV = iv.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('');

    return {'ciphertext': hexEncrypted, 'iv': hexIV};
  }
  ///Decrypt AES-CBC
  static List<int> decryptAesCbc(String hexCiphertext, String hexIV) {
    print('started decrypt');
    // Convert hex back to bytes
    final encryptedBytes = Uint8List.fromList(
      List.generate(
        hexCiphertext.length ~/ 2,
        (i) => int.parse(hexCiphertext.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );

    final ivBytes = Uint8List.fromList(
      List.generate(
        hexIV.length ~/ 2,
        (i) => int.parse(hexIV.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );

    final iv = encrypt.IV(ivBytes);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );

    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(encryptedBytes),
      iv: iv,
    );
    print('ended decrypt');
    return decrypted;
  }

}
