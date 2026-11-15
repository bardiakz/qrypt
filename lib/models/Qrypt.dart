import 'dart:typed_data';

import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/models/sign_method.dart';

import '../services/tag_manager.dart';
import 'encryption_method.dart';
import 'ml_dsa_key_pair.dart';
import 'obfuscation_method.dart';

/// Core payload container encapsulating text, crypto algorithms, key materials,
/// and pipeline state across compression, encryption, signing, and obfuscation.
class Qrypt {
  String text = '';
  Uint8List compressedText = Uint8List(0);
  List<int> deCompressedText = const <int>[];

  EncryptionMethod encryption = EncryptionMethod.none;
  ObfuscationMethod obfuscation = ObfuscationMethod.none;
  CompressionMethod compression = CompressionMethod.none;
  SignMethod sign = SignMethod.none;

  RSAKeyPair rsaKeyPair = RSAKeyPair.empty;
  String rsaReceiverPublicKey = 'noPublicKey';
  String rsaSenderPublicKey = 'noPublicKey';
  String customKey = 'noCustomKey';
  bool useTag = false;
  bool useCustomKey = false;
  String tag = '';
  Map<String, String>? customMap;

  // ML-KEM properties
  String inputCiphertext = '';
  Uint8List? ciphertext;
  Uint8List? kemSharedSecret;
  bool useKem = false;
  String kemReceiverPublicKey = 'noPublicKey';
  QryptKEMKeyPair? kemKeyPair;

  // ML-DSA properties
  Uint8List? dsaVerifyPublicKey;

  /// Backward-compatible alias for [dsaVerifyPublicKey].
  @Deprecated('Use dsaVerifyPublicKey instead')
  Uint8List? get dsaVerifyPublicKEy => dsaVerifyPublicKey;

  @Deprecated('Use dsaVerifyPublicKey instead')
  set dsaVerifyPublicKEy(Uint8List? value) => dsaVerifyPublicKey = value;

  QryptMLDSAKeyPair? dsaKeyPair;

  // RSA-PSS sign properties
  RSAKeyPair? rsaSignKeyPair;
  String? rsaVerifyPublicKey;

  Qrypt({
    required this.text,
    required this.encryption,
    required this.obfuscation,
    required CompressionMethod compression,
    required this.sign,
    this.customMap,
    this.kemReceiverPublicKey = 'noPublicKey',
    this.kemKeyPair,
  }) : compression =
           encryption == EncryptionMethod.mlKem
               ? CompressionMethod.none
               : compression;

  Qrypt.withTag({
    required this.text,
    required this.encryption,
    required this.obfuscation,
    required CompressionMethod compression,
    required this.useTag,
    required this.sign,
    this.customMap,
    this.kemReceiverPublicKey = 'noPublicKey',
    this.kemKeyPair,
  }) : compression =
           encryption == EncryptionMethod.mlKem
               ? CompressionMethod.none
               : compression {
    if (useTag) {
      TagManager.setTag(this);
    }
  }

  Qrypt.withKem({
    required this.text,
    required this.obfuscation,
    required this.useTag,
    required this.kemReceiverPublicKey,
    this.kemKeyPair,
    required this.sign,
    this.customMap,
  }) : encryption = EncryptionMethod.mlKem,
       compression = CompressionMethod.none {
    if (useTag) {
      TagManager.setTag(this);
    }
  }

  Qrypt.withRSA({
    required this.text,
    required this.encryption,
    required this.obfuscation,
    required this.compression,
    required this.useTag,
    required this.rsaKeyPair,
    required this.rsaReceiverPublicKey,
    required this.sign,
    this.customMap,
  }) {
    if (encryption == EncryptionMethod.rsa) {
      if (rsaReceiverPublicKey.isEmpty ||
          rsaReceiverPublicKey == 'noPublicKey') {
        throw ArgumentError(
          'Valid RSA receiver public key is required for RSA encryption',
        );
      }
      if (!rsaReceiverPublicKey.contains('BEGIN PUBLIC KEY')) {
        throw ArgumentError('Invalid RSA public key format');
      }
    }

    if (useTag) {
      TagManager.setTag(this);
    }
  }

  Qrypt.autoDecrypt({required this.text, this.customMap}) {
    useTag = true;
  }

  Qrypt.forKem({required this.ciphertext, required this.kemSharedSecret}) {
    useKem = true;
  }

  Qrypt.forKemDecrypt({required this.kemSharedSecret}) {
    useKem = true;
  }

  EncryptionMethod getEncryptionMethod() => encryption;
  ObfuscationMethod getObfuscationMethod() => obfuscation;
  CompressionMethod getCompressionMethod() => compression;
  SignMethod getSignMethod() => sign;

  /// Validates whether receiver public key parameters are valid for RSA encryption.
  bool isValidForRSAEncryption() {
    if (encryption != EncryptionMethod.rsa) {
      return true;
    }

    return rsaReceiverPublicKey.isNotEmpty &&
        rsaReceiverPublicKey != 'noPublicKey' &&
        rsaReceiverPublicKey.contains('BEGIN PUBLIC KEY');
  }

  /// Sets RSA key pair and receiver public key parameters with validation.
  void setRSAParameters(RSAKeyPair keyPair, String publicKey) {
    if (publicKey.isEmpty || publicKey == 'noPublicKey') {
      throw ArgumentError('Invalid public key provided');
    }
    if (!publicKey.contains('BEGIN PUBLIC KEY')) {
      throw ArgumentError('Invalid public key format');
    }

    rsaKeyPair = keyPair;
    rsaReceiverPublicKey = publicKey.trim();
  }

  @override
  String toString() =>
      'Qrypt(enc: ${encryption.name}, comp: ${compression.name}, sign: ${sign.name}, obf: ${obfuscation.name}, tag: $tag)';
}
