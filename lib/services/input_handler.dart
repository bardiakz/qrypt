import 'dart:convert';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  final _defaultKey = encrypt.Key.fromUtf8(dotenv.env['ENCRYPTION_KEY']!);

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
    encrypt.Key useKey = qrypt.useCustomKey
        ? encrypt.Key.fromUtf8(qrypt.customKey)
        : _defaultKey;

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
          useKey,
        );
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;

      case EncryptionMethod.aesCtr:
        Map<String, String> encMap = Aes.encryptAesCtr(
          qrypt.compressedText,
          useKey,
        );
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;
      case EncryptionMethod.aesGcm:
        Map<String, String> encMap = Aes.encryptAesGcm(
          qrypt.compressedText,
          useKey,
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
      case EncryptionMethod.aesCtr:
      case EncryptionMethod.aesGcm:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) {
          throw FormatException(
            'Invalid AES format - expected format: ciphertext:iv',
          );
        }

        // Determine which key to use
        encrypt.Key keyToUse;
        // if (qrypt.customKey.isNotEmpty) {
        //   // Use custom key if provided
        //   try {
        //     keyToUse = encrypt.Key.fromUtf8(qrypt.customKey!);
        //   } catch (e) {
        //     throw Exception('Invalid custom key format: $e');
        //   }
        // } else {
        //   // Use default key
        //   keyToUse = _defaultKey;
        // }
        keyToUse = _defaultKey;

        // First attempt with the determined key
        try {
          final decryptedData = _decryptWithAESKey(
            qrypt.getEncryptionMethod(),
            parts[0],
            parts[1],
            keyToUse,
          );

          if (decryptedData == null) {
            throw Exception(
              'Decryption returned null - invalid key or corrupted data',
            );
          }

          qrypt.deCompressedText = decryptedData;
          return qrypt;
        } catch (firstAttemptError) {
          if (kDebugMode) {
            print('First decryption attempt failed: $firstAttemptError');
          }

          // If we used custom key and it failed, throw error immediately
          if (qrypt.customKey.isNotEmpty) {
            throw Exception(
              'Decryption failed with provided custom key: $firstAttemptError',
            );
          }

          // If we used default key and context is available, try prompting for custom key
          if (buildContext.mounted) {
            final customKey = await _showCustomKeyDialog(buildContext);
            if (customKey != null && customKey.isNotEmpty) {
              try {
                final customEncryptKey = encrypt.Key.fromUtf8(customKey);
                final decryptedData = _decryptWithAESKey(
                  qrypt.getEncryptionMethod(),
                  parts[0],
                  parts[1],
                  customEncryptKey,
                );

                if (decryptedData == null) {
                  throw Exception('Decryption with custom key returned null');
                }

                qrypt.deCompressedText = decryptedData;

                // Show success feedback
                if (buildContext.mounted) {
                  ScaffoldMessenger.of(buildContext).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Successfully decrypted with custom key'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                return qrypt;
              } catch (customKeyError) {
                if (kDebugMode) {
                  print('Custom key decryption failed: $customKeyError');
                }
                throw Exception(
                  'Decryption failed with both default and custom keys: $customKeyError',
                );
              }
            } else {
              // User chose not to provide custom key
              throw Exception(
                'Decryption failed with default key. Custom key may be required.',
              );
            }
          } else {
            // Context not available for dialog
            throw Exception(
              'Decryption failed with default key. Custom key may be required.',
            );
          }
        }

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
                  backgroundColor: Colors.green,
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
                  backgroundColor: Colors.orange,
                ),
              );
            }
            // Note: Not throwing exception to allow data access despite signature failure
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

  Uint8List? _decryptWithAESKey(
    EncryptionMethod method,
    String ciphertext,
    String iv,
    encrypt.Key key,
  ) {
    try {
      switch (method) {
        case EncryptionMethod.aesCbc:
          final result = Aes.decryptAesCbc(ciphertext, iv, key);
          // Convert List<int> to Uint8List if needed
          if (result is! Uint8List) {
            return Uint8List.fromList(result);
          }
          return result as Uint8List?;

        case EncryptionMethod.aesCtr:
          final result = Aes.decryptAesCtr(ciphertext, iv, key);
          // Convert List<int> to Uint8List if needed
          if (result is! Uint8List) {
            return Uint8List.fromList(result);
          }
          return result as Uint8List?;

        case EncryptionMethod.aesGcm:
          final result = Aes.decryptAesGcm(ciphertext, iv, key);
          // Convert List<int> to Uint8List if needed, handle null case
          if (result == null) {
            return null;
          }
          if (result is! Uint8List) {
            return Uint8List.fromList(result);
          }
          return result as Uint8List?;

        default:
          throw Exception('Invalid AES encryption method: $method');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AES decryption error: $e');
      }
      return null; // Return null on any decryption error
    }
  }

  Future<String?> _showCustomKeyDialog(BuildContext context) async {
    final TextEditingController keyController = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.key, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text('Custom Key Required'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decryption failed with the default key. This content appears to be encrypted with a custom AES key.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: keyController,
                    decoration: InputDecoration(
                      labelText: 'Enter Custom AES Key',
                      hintText: '16, 24, or 32 characters',
                      prefixIcon: Icon(Icons.vpn_key),
                      border: OutlineInputBorder(),
                      errorText: errorText,
                      helperText:
                          'Current length: ${keyController.text.length}',
                    ),
                    maxLines: 1,
                    autofocus: true,
                    onChanged: (value) {
                      setState(() {
                        final length = value.length;
                        if (value.isNotEmpty &&
                            length != 16 &&
                            length != 24 &&
                            length != 32) {
                          errorText =
                              'Key must be exactly 16, 24, or 32 characters';
                        } else {
                          errorText = null;
                        }
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• AES-128: 16 characters\n• AES-192: 24 characters\n• AES-256: 32 characters',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: errorText != null || keyController.text.isEmpty
                      ? null
                      : () {
                          final key = keyController.text.trim();
                          if (key.length == 16 ||
                              key.length == 24 ||
                              key.length == 32) {
                            Navigator.of(context).pop(key);
                          }
                        },
                  child: Text('Try Key'),
                ),
              ],
            );
          },
        );
      },
    );
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
