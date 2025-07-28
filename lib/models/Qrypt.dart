import 'dart:convert';
import 'dart:typed_data';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/models/sign_method.dart';
import '../services/tag_manager.dart';
import 'encryption_method.dart';
import 'ml_dsa_key_pair.dart';
import 'obfuscation_method.dart';

class Qrypt {
  String text = '';
  Uint8List compressedText = utf8.encode('');
  List<int> deCompressedText = utf8.encode('');
  late final EncryptionMethod encryption;
  late final ObfuscationMethod obfuscation;
  late final CompressionMethod compression;
  SignMethod sign = SignMethod.none;
  RSAKeyPair rsaKeyPair = RSAKeyPair(
    id: '',
    name: '',
    publicKey: '',
    privateKey: '',
    createdAt: DateTime.now(),
  );
  String rsaReceiverPublicKey = 'noPublicKey';
  String rsaSenderPublicKey = 'noPublicKey';
  String customKey = 'noCustomKey';
  bool useTag = false;
  bool useCustomKey = false;
  String tag = '';

  //kem properties
  String inputCiphertext = '';
  Uint8List? ciphertext;
  Uint8List? kemSharedSecret;
  bool useKem = false;

  //dsa properties
  Uint8List? dsaVerifyPublicKEy;
  QryptMLDSAKeyPair? dsaKeyPair;

  Qrypt.withTag({
    required this.text,
    required this.encryption,
    required this.obfuscation,
    required this.compression,
    required this.useTag,
    required this.sign,
  }) {
    if (useTag == true) {
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
  }) {
    // Validate RSA parameters
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

    if (useTag == true) {
      TagManager.setTag(this);
    }
  }

  Qrypt.autoDecrypt({required this.text}) {
    useTag = true;
  }

  Qrypt.forKem({required this.ciphertext, required this.kemSharedSecret}) {
    useKem = true;
  }

  Qrypt.forKemDecrypt({required this.kemSharedSecret}) {
    useKem = true;
  }

  Qrypt({
    required this.text,
    required this.encryption,
    required this.obfuscation,
    required this.compression,
    required this.sign,
  });

  EncryptionMethod getEncryptionMethod() {
    return encryption;
  }

  ObfuscationMethod getObfuscationMethod() {
    return obfuscation;
  }

  CompressionMethod getCompressionMethod() {
    return compression;
  }

  SignMethod getSignMethod() {
    return sign;
  }

  // Validation method to check if RSA parameters are valid
  bool isValidForRSAEncryption() {
    if (encryption != EncryptionMethod.rsa) {
      return true; // Not RSA, so RSA validation doesn't apply
    }

    return rsaReceiverPublicKey.isNotEmpty &&
        rsaReceiverPublicKey != 'noPublicKey' &&
        rsaReceiverPublicKey.contains('BEGIN PUBLIC KEY');
  }

  // Method to set RSA parameters with validation
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
}
