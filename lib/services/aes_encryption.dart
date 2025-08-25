import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import '../models/encryption_method.dart';

class Aes extends Encryption {
  @override
  String get tag => 'aes';

  // static final _key = encrypt.Key.fromUtf8(dotenv.env['ENCRYPTION_KEY']!);

  ///Encrypt AES-CBC
  static Map<String, String> encryptAesCbc(
    Uint8List compressed,
    encrypt.Key key,
  ) {
    final iv = encrypt.IV.fromLength(16);

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
    final iv = encrypt.IV.fromLength(16);
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

  static Uint8List _fromHex(String hex) {
    return Uint8List.fromList(
      List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }
}
