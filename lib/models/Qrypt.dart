import 'dart:convert';
import 'dart:typed_data';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import '../services/tag_manager.dart';
import 'encryption_method.dart';
import 'obfuscation_method.dart';

class Qrypt {
  String text = '';
  Uint8List compressedText = utf8.encode('');
  List<int> deCompressedText = utf8.encode('');
  late final EncryptionMethod encryption;
  late final ObfuscationMethod obfuscation;
  late final CompressionMethod compression;
  RSAKeyPair rsaKeyPair = RSAKeyPair(
    id: '',
    name: '',
    publicKey: '',
    privateKey: '',
    createdAt: DateTime.now(),
  );
  String rsaReceiverPublicKey = 'noPublicKey';
  String rsaSenderPublicKey = 'noPublicKey';
  bool useTag = false;
  String tag = '';

  Qrypt.withTag({
    required this.text,
    required this.encryption,
    required this.obfuscation,
    required this.compression,
    required this.useTag,
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

  Qrypt({
    required this.text,
    required this.encryption,
    required this.obfuscation,
    required this.compression,
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
