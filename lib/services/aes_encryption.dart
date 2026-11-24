import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import '../models/encryption_method.dart';

/// Converts any stored or entered key string into an encrypt.Key.
/// - 24-char Base64 ending in '==' decoding to 16 bytes -> encrypt.Key(bytes) (128-bit key)
/// - 48-char Hex string decoding to 24 bytes -> encrypt.Key(bytes) (192-bit key)
/// - 44-char Base64 string decoding to 32 bytes -> encrypt.Key(bytes) (256-bit key)
/// - 64-char Hex string decoding to 32 bytes -> encrypt.Key(bytes) (256-bit key)
/// - Otherwise -> encrypt.Key.fromUtf8(trimmed) (legacy raw text key)
encrypt.Key parseAesKey(String keyString) {
  final trimmed = keyString.trim();
  if (trimmed.length == 24 && trimmed.endsWith('==')) {
    try {
      final bytes = base64.decode(trimmed);
      if (bytes.length == 16) {
        return encrypt.Key(Uint8List.fromList(bytes));
      }
    } catch (_) {}
  }
  if (trimmed.length == 48 && RegExp(r'^[0-9a-fA-F]{48}$').hasMatch(trimmed)) {
    try {
      final bytes = Uint8List.fromList(
        List.generate(
          24,
          (i) => int.parse(trimmed.substring(i * 2, i * 2 + 2), radix: 16),
        ),
      );
      return encrypt.Key(bytes);
    } catch (_) {}
  }
  if (trimmed.length == 44) {
    try {
      final bytes = base64.decode(trimmed);
      if (bytes.length == 32) {
        return encrypt.Key(Uint8List.fromList(bytes));
      }
    } catch (_) {}
  }
  if (trimmed.length == 64 && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmed)) {
    try {
      final bytes = Uint8List.fromList(
        List.generate(
          32,
          (i) => int.parse(trimmed.substring(i * 2, i * 2 + 2), radix: 16),
        ),
      );
      return encrypt.Key(bytes);
    } catch (_) {}
  }
  return encrypt.Key.fromUtf8(trimmed);
}

class Aes extends Encryption {
  @override
  String get tag => 'aes';

  ///Encrypt AES-CBC
  static Map<String, String> encryptAesCbc(
    Uint8List compressed,
    encrypt.Key key,
  ) {
    final iv = encrypt.IV.fromSecureRandom(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
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
  static List<int> decryptAesCbc(
    String hexCiphertext,
    String hexIV,
    encrypt.Key key,
  ) {
    // Convert hex back to bytes
    final encryptedBytes = _fromHex(hexCiphertext);
    final ivBytes = _fromHex(hexIV);
    final iv = encrypt.IV(ivBytes);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(encryptedBytes),
      iv: iv,
    );
    return decrypted;
  }

  /// AES-GCM - Encrypt
  static Map<String, String> encryptAesGcm(Uint8List data, encrypt.Key key) {
    final iv = encrypt.IV.fromSecureRandom(12);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encryptBytes(data, iv: iv);

    return {
      'ciphertext': _toHex(encrypted.bytes), // includes auth tag at the end
      'iv': _toHex(iv.bytes),
    };
  }

  ///AES-GCM - Decrypt
  static List<int>? decryptAesGcm(
    String hexCiphertext,
    String hexIV,
    encrypt.Key key,
  ) {
    try {
      final encryptedBytes = _fromHex(hexCiphertext);
      final iv = encrypt.IV(_fromHex(hexIV));

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(encryptedBytes),
        iv: iv,
      );

      return decrypted;
    } catch (e) {
      debugPrint('GCM decryption failed: $e');
      return null;
    }
  }

  /// AES-CTR - Encrypt
  static Map<String, String> encryptAesCtr(Uint8List data, encrypt.Key key) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.ctr),
    );
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    return {'ciphertext': _toHex(encrypted.bytes), 'iv': _toHex(iv.bytes)};
  }

  /// AES-CTR - Decrypt
  static List<int> decryptAesCtr(
    String hexCiphertext,
    String hexIV,
    encrypt.Key key,
  ) {
    final encryptedBytes = _fromHex(hexCiphertext);
    final iv = encrypt.IV(_fromHex(hexIV));
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.ctr),
    );
    return encrypter.decryptBytes(encrypt.Encrypted(encryptedBytes), iv: iv);
  }

  //Utility methods
  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Parse a hexadecimal string into bytes.
  /// Throws [FormatException] if the hex string has an odd length or contains invalid hex characters.
  static Uint8List fromHex(String hex) {
    if (hex.length.isOdd) {
      throw FormatException(
        'Hex string must have an even length (got length ${hex.length})',
      );
    }
    return Uint8List.fromList(
      List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }

  static Uint8List _fromHex(String hex) => fromHex(hex);
}
