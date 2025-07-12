import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/encryption.dart';

class Aes extends Encryption {
  @override
  String get tag => 'aes';

  static final _key = encrypt.Key.fromUtf8(dotenv.env['ENCRYPTION_KEY']!);

  ///Encrypt
  static Map<String, String> encryptMessage(String plaintext) {
    final compressed = _compress(utf8.encode(plaintext));
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

    return {'ciphertext': hexEncrypted, 'iv': hexIV, 'tag': 'qmsa2'};
  }

  static String decryptMessage(String hexCiphertext, String hexIV) {
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

    return utf8.decode(_decompress(decrypted));
  }

  ///Compresses data using GZip
  static Uint8List _compress(List<int> data) {
    final encoder = GZipEncoder();
    return Uint8List.fromList(encoder.encode(data)!);
  }

  ///Decompresses data using GZip
  static List<int> _decompress(List<int> compressedData) {
    final decoder = GZipDecoder();
    return decoder.decodeBytes(compressedData);
  }

}
