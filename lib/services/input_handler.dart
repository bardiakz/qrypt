import 'dart:convert';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/tag_manager.dart';

import '../models/Qrypt.dart';
import '../models/compression_method.dart';
import '../models/obfuscation_method.dart';
import '../pages/widgets/RSA_key_selection_dialog.dart';
import '../providers/rsa_providers.dart';
import 'aes_encryption.dart';
import 'obfuscate.dart';

class InputHandler {
  static final _defaultKey = encrypt.Key.fromUtf8(
    dotenv.env['ENCRYPTION_KEY']!,
  );

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
        Map<String, String> encMap = Aes.encryptAesCbc(
          qrypt.compressedText,
          _defaultKey,
        );
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;

      case EncryptionMethod.aesCtr:
        Map<String, String> encMap = Aes.encryptAesCtr(
          qrypt.compressedText,
          _defaultKey,
        );
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;
      case EncryptionMethod.aesGcm:
        Map<String, String> encMap = Aes.encryptAesGcm(
          qrypt.compressedText,
          _defaultKey,
        );
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
          final String signature = await rsa.signWithPrivateKey(
            textToEncrypt,
            normalizedPrivateKey,
          );

          // Create a package containing both original data and signature
          final Map<String, String> signedPackage = {
            'data': textToEncrypt,
            'signature': signature,
          };

          // Convert to JSON string
          final String packageJson = jsonEncode(signedPackage);

          // Then encrypt the entire package using hybrid encryption
          Map<String, String> encryptedPackage = await rsa.encryptLargeData(
            packageJson,
            qrypt.rsaReceiverPublicKey,
          );

          // Combine the encrypted package into a single string
          String encryptedResult =
              '${encryptedPackage['encryptedData']}:${encryptedPackage['encryptedKey']}:${encryptedPackage['iv']}';

          // Convert RSA result to appropriate format for obfuscation
          if (usesMappedObfuscation) {
            Uint8List rsaBytes = base64.decode(
              base64.encode(utf8.encode(encryptedResult)),
            );
            qrypt.text = rsaBytes
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join('');
          } else if (usesBase64Obfuscation) {
            qrypt.text = encryptedResult;
          } else {
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

  Future<Qrypt> handleDecrypt(Qrypt qrypt, BuildContext buildContext) async {
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
          _defaultKey,
        ); //to be decompressed in the next phase
        return qrypt;
      case EncryptionMethod.aesCtr:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-CTR format');
        qrypt.deCompressedText = Aes.decryptAesCtr(
          parts[0],
          parts[1],
          _defaultKey,
        ); //to be decompressed in the next phase
        return qrypt;
      case EncryptionMethod.aesGcm:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-GCM format');
        qrypt.deCompressedText = Aes.decryptAesGcm(
          parts[0],
          parts[1],
          _defaultKey,
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
          qrypt.rsaSenderPublicKey = decryptPublicKeyGlobal;

          // Validate keys
          if (qrypt.rsaKeyPair.privateKey.isEmpty ||
              qrypt.rsaKeyPair.privateKey == 'noPrivateKey' ||
              !qrypt.rsaKeyPair.privateKey.contains('BEGIN PRIVATE KEY')) {
            throw Exception('No valid RSA private key provided for decryption');
          }

          if (qrypt.rsaSenderPublicKey.isEmpty ||
              qrypt.rsaSenderPublicKey == 'noPublicKey' ||
              !qrypt.rsaSenderPublicKey.contains('BEGIN PUBLIC KEY') ||
              qrypt.rsaSenderPublicKey == 'n') {
            throw Exception(
              'No valid RSA public key provided for signature verification',
            );
          }

          RSAKeyService rsa = RSAKeyService();

          // Convert obfuscated text back to encrypted format
          String rsaInputText;
          if (usesMappedObfuscation) {
            List<int> bytes = [];
            for (int i = 0; i < qrypt.text.length; i += 2) {
              String hexByte = qrypt.text.substring(i, i + 2);
              bytes.add(int.parse(hexByte, radix: 16));
            }
            rsaInputText = utf8.decode(bytes);
          } else if (usesBase64Obfuscation) {
            rsaInputText = qrypt.text;
          } else {
            rsaInputText = utf8.decode(base64.decode(qrypt.text));
          }

          // Parse the hybrid encryption format
          List<String> parts = parseByColon(rsaInputText);
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

          // Decrypt the package
          String decryptedPackageJson = await rsa.decryptLargeData(
            encryptedPackage,
            qrypt.rsaKeyPair.privateKey,
          );

          // Parse the JSON package
          Map<String, dynamic> signedPackage = jsonDecode(decryptedPackageJson);
          String originalData = signedPackage['data'];
          String signature = signedPackage['signature'];

          // Verify the signature
          bool isSignatureValid = await rsa.verifyWithPublicKey(
            originalData,
            signature,
            qrypt.rsaSenderPublicKey,
          );

          if (isSignatureValid) {
            if (kDebugMode) {
              print('Signature verification successful ✓');
            }
            if (buildContext.mounted) {
              ScaffoldMessenger.of(buildContext).showSnackBar(
                const SnackBar(
                  content: Text('Signature verification successful ✓'),
                ),
              );
            }
          } else {
            if (kDebugMode) {
              print(
                '⚠️ WARNING: Signature verification failed! Data may be tampered with.',
              );
            }
            if (buildContext.mounted) {
              ScaffoldMessenger.of(buildContext).showSnackBar(
                const SnackBar(
                  content: Text(
                    '⚠️ WARNING: Signature verification failed! Data may be tampered with.',
                  ),
                ),
              );
            }
            // throw Exception('Signature verification failed - data integrity compromised');
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
      qrypt = await handleDecrypt(qrypt, context);
      qrypt = handleDeCompression(qrypt);
    } else {
      String? tag = TagManager.matchedTag(qrypt.text);
      if (tag == null) {
        qrypt.text = 'Invalid tag format';
        // throw FormatException('Invalid tag format');
      } else {
        if (kDebugMode) {
          print('tag is $tag');
        }
        qrypt.text = qrypt.text.substring(tag.length);
        if (kDebugMode) {
          print('tag removed text: ${qrypt.text}');
        }
        final methods = TagManager.getMethodsFromTag(tag);
        qrypt.obfuscation = methods!.obfuscation;
        qrypt.encryption = methods.encryption;
        qrypt.compression = methods.compression;
        qrypt = handleDeObfs(qrypt);
        if (qrypt.encryption == EncryptionMethod.rsa ||
            qrypt.encryption == EncryptionMethod.rsaSign) {
          final selectedKeyPair = await showRSAKeySelectionDialog(
            context: context,
            primaryColor: primaryColor,
            title: 'Select Decryption Key',
            message:
                'This content was encrypted with RSA. Please select the appropriate key pair for decryption.',
            publicKeyRequired: qrypt.encryption == EncryptionMethod.rsaSign,
          );
          if (selectedKeyPair == null) {
            throw Exception('Decryption cancelled: No key pair selected');
          }
          qrypt.rsaKeyPair = selectedKeyPair;
        }
        qrypt = await handleDecrypt(qrypt, context);
        qrypt = handleDeCompression(qrypt);
      }
    }
    return qrypt;
  }

  static List<String> parseByColon(String input) {
    List<String> parts;
    parts = input.split(':');
    if (kDebugMode) {
      print(
        'parsed the text with size ${parts.length} : ${parts[0]} and ${parts[1]} ',
      );
    }
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
