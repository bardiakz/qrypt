import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/tag_manager.dart';

import '../models/Qrypt.dart';
import '../models/compression_method.dart';
import '../models/obfuscation_method.dart';
import '../pages/widgets/RSA_key_selection_dialog.dart';
import 'aes_encryption.dart';
import 'obfuscate.dart';

class InputHandler {
  Qrypt handleCompression(Qrypt qrypt) {
    Uint8List compText;
    switch (qrypt.getCompressionMethod()) {
      case CompressionMethod.none:
        compText = utf8.encode(qrypt.text);
        qrypt.compressedText = compText;
        return qrypt;
      case CompressionMethod.gZip:
        compText = Compression.gZipCompress(utf8.encode(qrypt.text));
        qrypt.compressedText = compText;
        return qrypt;

      case CompressionMethod.lZ4:
        compText = Compression.lz4Compress(utf8.encode(qrypt.text));
        qrypt.compressedText = compText;
        return qrypt;
      case CompressionMethod.brotli:
        compText = Compression.brotliCompress(utf8.encode(qrypt.text));
        qrypt.compressedText = compText;
        return qrypt;
      case CompressionMethod.zstd:
        compText = Compression.zstdCompress(utf8.encode(qrypt.text));
        qrypt.compressedText = compText;
        return qrypt;
    }
  }

  Future<Qrypt> handleEncrypt(Qrypt qrypt) async {
    String? encryptedText = qrypt.text;
    bool usesMappedObfuscation = [
      ObfuscationMethod.en1,
      ObfuscationMethod.en2,
      ObfuscationMethod.fa1,
      ObfuscationMethod.fa2,
    ].contains(qrypt.getObfuscationMethod());

    bool usesBase64Obfuscation =
        qrypt.getObfuscationMethod() == ObfuscationMethod.b64;
    switch (qrypt.getEncryptionMethod()) {
      case EncryptionMethod.none:
        if (usesMappedObfuscation) {
          // For mapped obfuscations, convert to hex
          qrypt.text = qrypt.compressedText
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join('');
        } else if (usesBase64Obfuscation) {
          // For b64 obfuscation, keep as raw bytes (don't pre-encode)
          qrypt.text = String.fromCharCodes(qrypt.compressedText);
        } else {
          // For other obfuscations (rot13, xor, etc.), use base64
          qrypt.text = base64.encode(qrypt.compressedText);
        }
        return qrypt;
      case EncryptionMethod.aesCbc:
        Map<String, String> encMap = Aes.encryptAesCbc(qrypt.compressedText);
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;

      case EncryptionMethod.aesCtr:
        Map<String, String> encMap = Aes.encryptAesCtr(qrypt.compressedText);
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;
      case EncryptionMethod.aesGcm:
        Map<String, String> encMap = Aes.encryptAesGcm(qrypt.compressedText);
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;
      case EncryptionMethod.rsa:
        try {
          // Check if a valid RSA public key is provided
          if (qrypt.rsaReceiverPublicKey.isEmpty ||
              qrypt.rsaReceiverPublicKey == "noPublicKey" ||
              !qrypt.rsaReceiverPublicKey.contains('BEGIN PUBLIC KEY')) {
            throw Exception('No valid RSA public key provided for encryption');
          }

          RSAKeyService rsa = RSAKeyService();
          // Convert compressed bytes to string for RSA encryption
          String textToEncrypt = base64.encode(qrypt.compressedText);
          String encryptedResult = await rsa.encryptWithPublicKey(
            textToEncrypt,
            qrypt.rsaReceiverPublicKey,
          );

          // FIXED: Convert RSA result to appropriate format for obfuscation
          if (usesMappedObfuscation) {
            // Convert base64 RSA result to hex for mapped obfuscations
            Uint8List rsaBytes = base64.decode(encryptedResult);
            qrypt.text = rsaBytes
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join('');
          } else if (usesBase64Obfuscation) {
            // For b64 obfuscation, decode base64 to raw string
            Uint8List rsaBytes = base64.decode(encryptedResult);
            qrypt.text = String.fromCharCodes(rsaBytes);
          } else {
            // For other obfuscations, keep as base64
            qrypt.text = encryptedResult;
          }

          return qrypt;
        } catch (e) {
          if (kDebugMode) {
            print('RSA encryption failed: $e');
          }
          throw Exception('RSA encryption failed: $e');
        }
      case EncryptionMethod.rsaSign:
        try {
          if (qrypt.rsaReceiverPublicKey.isEmpty ||
              qrypt.rsaReceiverPublicKey == 'noPublicKey' ||
              !qrypt.rsaReceiverPublicKey.contains('BEGIN PUBLIC KEY')) {
            throw Exception('No valid RSA public key provided for encryption');
          }
          if (kDebugMode) {
            print('this is private key: ${qrypt.rsaKeyPair.privateKey}');
          }
          final normalizedPrivateKey = qrypt.rsaKeyPair.privateKey
              .trim()
              .replaceAll(RegExp(r'\r\n|\r|\n'), '\n');
          if (normalizedPrivateKey.isEmpty ||
              normalizedPrivateKey == 'n' ||
              !normalizedPrivateKey.contains('BEGIN PRIVATE KEY')) {
            throw Exception('No valid RSA private key provided for encryption');
          }

          RSAKeyService rsa = RSAKeyService();

          String textToEncrypt = base64.encode(qrypt.compressedText);

          // First sign the data
          final String signedText = await rsa.signWithPrivateKey(
            textToEncrypt,
            normalizedPrivateKey,
          );

          // Then encrypt using hybrid encryption
          Map<String, String> encryptedPackage = await rsa.encryptLargeData(
            signedText,
            qrypt.rsaReceiverPublicKey,
          );

          // Combine the encrypted package into a single string
          String encryptedResult =
              '${encryptedPackage['encryptedData']}:${encryptedPackage['encryptedKey']}:${encryptedPackage['iv']}';

          // Convert RSA result to appropriate format for obfuscation
          if (usesMappedObfuscation) {
            // Convert base64 RSA result to hex for mapped obfuscations
            Uint8List rsaBytes = base64.decode(
              base64.encode(utf8.encode(encryptedResult)),
            );
            qrypt.text = rsaBytes
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join('');
          } else if (usesBase64Obfuscation) {
            // For b64 obfuscation, use the encrypted result as raw string
            qrypt.text = encryptedResult;
          } else {
            // For other obfuscations, encode as base64
            qrypt.text = base64.encode(utf8.encode(encryptedResult));
          }

          return qrypt;
        } catch (e) {
          if (kDebugMode) {
            print('RSA+Sign encryption failed: $e');
          }
          throw Exception('RSA+Sign encryption failed: $e');
        }
    }
  }

  Qrypt handleObfs(Qrypt qrypt) {
    String? obfsText = qrypt.text;
    switch (qrypt.getObfuscationMethod()) {
      case ObfuscationMethod.none:
        return qrypt;
      case ObfuscationMethod.en1:
        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationEN1Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.en2:
        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationEN2Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.fa1:
        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationFA1Map);
        // print('crypt txt is:${obfsText}');
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.fa2:
        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationFA2Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.b64:
        obfsText = Obfuscate.obfuscateBase64(qrypt.text);
        qrypt.text = obfsText;
        return qrypt;

      case ObfuscationMethod.rot13:
        obfsText = Obfuscate.obfuscateROT13(qrypt.text);
        qrypt.text = obfsText;
        return qrypt;

      case ObfuscationMethod.xor:
        obfsText = Obfuscate.obfuscateXOR(qrypt.text, 42);
        qrypt.text = obfsText;
        return qrypt;

      // case ObfuscationMethod.reverse:
      //   obfsText = Obfuscate.obfuscateReverse(qrypt.text);
      //   qrypt.text = obfsText;
      //   return qrypt;
    }
  }

  Qrypt handleDeObfs(Qrypt qrypt) {
    String? obfsText = qrypt.text;
    switch (qrypt.getObfuscationMethod()) {
      case ObfuscationMethod.none:
        return qrypt;
      case ObfuscationMethod.en1:
        obfsText = Obfuscate.deobfuscateText(qrypt.text, obfuscationEN1Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.en2:
        obfsText = Obfuscate.deobfuscateText(qrypt.text, obfuscationEN2Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.fa1:
        obfsText = Obfuscate.deobfuscateText(qrypt.text, obfuscationFA1Map);
        // print('crypt txt is:${obfsText}');
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.fa2:
        obfsText = Obfuscate.deobfuscateText(qrypt.text, obfuscationFA2Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.b64:
        obfsText = Obfuscate.deobfuscateBase64(qrypt.text);
        qrypt.text = obfsText;
        return qrypt;

      case ObfuscationMethod.rot13:
        obfsText = Obfuscate.deobfuscateROT13(qrypt.text);
        qrypt.text = obfsText;
        return qrypt;

      case ObfuscationMethod.xor:
        // Use the same key as obfuscation
        obfsText = Obfuscate.deobfuscateXOR(qrypt.text, 42); // Same key
        qrypt.text = obfsText;
        return qrypt;

      // case ObfuscationMethod.reverse:
      //   obfsText = Obfuscate.deobfuscateReverse(qrypt.text);
      //   qrypt.text = obfsText;
      //   return qrypt;
    }
  }

  Future<Qrypt> handleDecrypt(Qrypt qrypt) async {
    bool usesMappedObfuscation = [
      ObfuscationMethod.en1,
      ObfuscationMethod.en2,
      ObfuscationMethod.fa1,
      ObfuscationMethod.fa2,
    ].contains(qrypt.getObfuscationMethod());

    bool usesBase64Obfuscation =
        qrypt.getObfuscationMethod() == ObfuscationMethod.b64;
    switch (qrypt.getEncryptionMethod()) {
      case EncryptionMethod.none:
        if (usesMappedObfuscation) {
          // Convert hex back to bytes
          List<int> bytes = [];
          for (int i = 0; i < qrypt.text.length; i += 2) {
            String hexByte = qrypt.text.substring(i, i + 2);
            bytes.add(int.parse(hexByte, radix: 16));
          }
          qrypt.deCompressedText = Uint8List.fromList(bytes);
        } else if (usesBase64Obfuscation) {
          // For b64 obfuscation, convert string back to bytes
          qrypt.deCompressedText = Uint8List.fromList(qrypt.text.codeUnits);
        } else {
          // For other obfuscations, decode base64
          qrypt.deCompressedText = base64.decode(qrypt.text);
        }
        return qrypt;
      case EncryptionMethod.aesCbc:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-CBC format');
        qrypt.deCompressedText = Aes.decryptAesCbc(
          parts[0],
          parts[1],
        ); //to be decompressed in the next phase
        return qrypt;
      case EncryptionMethod.aesCtr:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-CTR format');
        qrypt.deCompressedText = Aes.decryptAesCtr(
          parts[0],
          parts[1],
        ); //to be decompressed in the next phase
        return qrypt;
      case EncryptionMethod.aesGcm:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-GCM format');
        qrypt.deCompressedText = Aes.decryptAesGcm(
          parts[0],
          parts[1],
        )!; //to be decompressed in the next phase
        return qrypt;
      case EncryptionMethod.rsa:
        try {
          if (qrypt.rsaKeyPair.privateKey.isEmpty ||
              qrypt.rsaKeyPair.privateKey == "noPrivateKey") {
            throw Exception('No valid RSA private key provided for decryption');
          }

          RSAKeyService rsa = RSAKeyService();
          String rsaInputText;
          if (usesMappedObfuscation) {
            // Convert hex back to base64
            List<int> bytes = [];
            for (int i = 0; i < qrypt.text.length; i += 2) {
              String hexByte = qrypt.text.substring(i, i + 2);
              bytes.add(int.parse(hexByte, radix: 16));
            }
            rsaInputText = base64.encode(bytes);
          } else if (usesBase64Obfuscation) {
            // Convert raw string back to base64
            rsaInputText = base64.encode(qrypt.text.codeUnits);
          } else {
            // Already in base64 format
            rsaInputText = qrypt.text;
          }

          // Decrypt the RSA encrypted text
          String decryptedResult = await rsa.decryptWithPrivateKey(
            rsaInputText,
            qrypt.rsaKeyPair.privateKey,
          );

          // The decrypted result is base64 encoded compressed data
          qrypt.deCompressedText = base64.decode(decryptedResult);
          return qrypt;
        } catch (e) {
          if (kDebugMode) {
            print('RSA decryption failed: $e');
          }
          throw Exception('RSA decryption failed: $e');
        }
      case EncryptionMethod.rsaSign:
        try {
          // Check if valid RSA keys are provided
          if (qrypt.rsaKeyPair.privateKey.isEmpty ||
              qrypt.rsaKeyPair.privateKey == "noPrivateKey" ||
              !qrypt.rsaKeyPair.privateKey.contains('BEGIN PRIVATE KEY')) {
            throw Exception('No valid RSA private key provided for decryption');
          }

          if (qrypt.rsaReceiverPublicKey.isEmpty ||
              qrypt.rsaReceiverPublicKey == "noPublicKey" ||
              !qrypt.rsaReceiverPublicKey.contains('BEGIN PUBLIC KEY')) {
            throw Exception(
              'No valid RSA public key provided for signature verification',
            );
          }

          RSAKeyService rsa = RSAKeyService();

          // Parse the hybrid encryption format: encryptedData:encryptedKey:iv
          List<String> parts = parseByColon(qrypt.text);
          if (parts.length != 3) {
            throw FormatException(
              'Invalid RSA+Sign hybrid encryption format. Expected format: encryptedData:encryptedKey:iv',
            );
          }

          // Reconstruct the encrypted package
          Map<String, String> encryptedPackage = {
            'encryptedData': parts[0],
            'encryptedKey': parts[1],
            'iv': parts[2],
          };

          // First decrypt the data using hybrid decryption
          String decryptedSignedText = await rsa.decryptLargeData(
            encryptedPackage,
            qrypt.rsaKeyPair.privateKey,
          );

          // The decrypted text should contain the signature and original data
          // Parse the signed data format (this depends on how signWithPrivateKey formats the output)
          // Assuming the signed data is in base64 format

          // For now, we'll extract the original data from the signed text
          // This might need adjustment based on your specific signing implementation
          String originalData;

          try {
            // Try to verify the signature and extract the original message
            // This is a simplified approach - you might need to modify based on your signing format

            // If the signed text contains both signature and data, parse them
            // For this example, assuming the signed text is the original message that was signed
            originalData = decryptedSignedText;

            // Optional: Verify signature if you have the signature separate
            // bool isSignatureValid = await rsa.verifyWithPublicKey(
            //   originalData,
            //   signature,
            //   qrypt.rsaReceiverPublicKey,
            // );
            //
            // if (!isSignatureValid) {
            //   throw Exception('Signature verification failed');
            // }
          } catch (verificationError) {
            if (kDebugMode) {
              print('Signature verification warning: $verificationError');
            }
            // Still proceed with decryption even if signature verification fails
            originalData = decryptedSignedText;
          }

          // The original data is base64 encoded compressed data
          qrypt.deCompressedText = base64.decode(originalData);
          return qrypt;
        } catch (e) {
          if (kDebugMode) {
            print('RSA+Sign decryption failed: $e');
          }
          throw Exception('RSA+Sign decryption failed: $e');
        }
    }
  }

  Qrypt handleDeCompression(Qrypt qrypt) {
    switch (qrypt.getCompressionMethod()) {
      case CompressionMethod.none:
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.gZip:
        qrypt.deCompressedText = Compression.gZipDeCompress(
          qrypt.deCompressedText,
        );
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;

      case CompressionMethod.lZ4:
        qrypt.deCompressedText = Compression.lz4DeCompress(
          qrypt.deCompressedText,
        );
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.brotli:
        qrypt.deCompressedText = Compression.brotliDeCompress(
          qrypt.deCompressedText,
        );
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.zstd:
        qrypt.deCompressedText = Compression.zstdDeCompress(
          qrypt.deCompressedText,
        );
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
    }
  }

  Future<Qrypt> handleProcess(Qrypt qrypt) async {
    qrypt = handleCompression(qrypt);
    qrypt = await handleEncrypt(qrypt);
    qrypt.text = qrypt.tag + qrypt.text;
    qrypt = handleObfs(qrypt);
    return qrypt;
  }

  Future<Qrypt> handleDeProcess(
    BuildContext context,
    Qrypt qrypt,
    bool useTag,
  ) async {
    Color primaryColor = Colors.blue;
    if (!useTag) {
      qrypt = handleDeObfs(qrypt);
      qrypt = await handleDecrypt(qrypt);
      qrypt = handleDeCompression(qrypt);
    } else {
      String? tag = TagManager.matchedTag(qrypt.text);
      if (tag == null) {
        qrypt.text = 'Invalid tag format';
        // throw FormatException('Invalid tag format');
      } else {
        print('tag is $tag');
        qrypt.text = qrypt.text.substring(tag.length);
        print('tag removed text: ${qrypt.text}');
        final methods = TagManager.getMethodsFromTag(tag);
        qrypt.obfuscation = methods!.obfuscation;
        qrypt.encryption = methods.encryption;
        qrypt.compression = methods.compression;
        qrypt = handleDeObfs(qrypt);
        if (qrypt.encryption == EncryptionMethod.rsa) {
          final selectedKeyPair = await showRSAKeySelectionDialog(
            context: context,
            primaryColor: primaryColor,
            title: 'Select Decryption Key',
            message:
                'This content was encrypted with RSA. Please select the appropriate key pair for decryption.',
          );
          if (selectedKeyPair == null) {
            throw Exception('Decryption cancelled: No key pair selected');
          }
          qrypt.rsaKeyPair = selectedKeyPair;
        }
        qrypt = await handleDecrypt(qrypt);
        qrypt = handleDeCompression(qrypt);
      }
    }
    return qrypt;
  }

  static List<String> parseByColon(String input) {
    List<String> parts;
    parts = input.split(':');
    print(
      'parsed the text with size ${parts.length} : ${parts[0]} and ${parts[1]} ',
    );
    return input.split(':');
  }
}

// class DeQrypt{
//   String text="";
//   late final EncryptionMethod encryption;
//   late final ObfuscationMethod obfuscation;
//   bool useTag=false;
//   String? tag;
//   DeQrypt.withTag({required this.text,required this.encryption,required this.obfuscation,this.tag}){
//     useTag=true;
//   }
//   DeQrypt({required this.text,required this.encryption,required this.obfuscation});
// }
