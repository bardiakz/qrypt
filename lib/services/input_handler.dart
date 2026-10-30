import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oqs/oqs.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/exceptions.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/kem/kem_service.dart';
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/tag_manager.dart';
import '../models/Qrypt.dart';
import '../models/aes_key.dart';
import '../models/compression_method.dart';
import '../models/obfuscation_method.dart';
import '../models/sign_method.dart';
import '../pages/widgets/ml_dsa/ml_dsa_key_selection_dialog.dart';
import '../pages/widgets/rsa/RSA_key_selection_dialog.dart';
import '../providers/rsa_providers.dart';
import 'aes/aes_key_storage_service.dart';
import 'aes_encryption.dart';
import 'ml_dsa/ml_dsa_key_service.dart';
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
    final encMethod = qrypt.getEncryptionMethod();
    final isAes =
        encMethod == EncryptionMethod.aesCbc ||
        encMethod == EncryptionMethod.aesCtr ||
        encMethod == EncryptionMethod.aesGcm;

    encrypt.Key? useKey;
    if (isAes) {
      if (!qrypt.useCustomKey ||
          qrypt.customKey.isEmpty ||
          qrypt.customKey == 'noCustomKey') {
        throw const MissingKeyException(
          'An AES key is required for encryption. Please select or generate an AES key.',
        );
      }
      useKey = encrypt.Key.fromUtf8(qrypt.customKey);
    }

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
        if (qrypt.getObfuscationMethod() == ObfuscationMethod.none) {
          qrypt.text = base64.encode(qrypt.compressedText);
        } else if (usesMappedObfuscation) {
          // For mapped obfuscations, convert to hex using StringBuffer for efficiency
          StringBuffer hexBuffer = StringBuffer();
          for (var byte in qrypt.compressedText) {
            hexBuffer.write(byte.toRadixString(16).padLeft(2, '0'));
          }
          qrypt.text = hexBuffer.toString();
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
          useKey!,
        );
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;

      case EncryptionMethod.aesCtr:
        Map<String, String> encMap = Aes.encryptAesCtr(
          qrypt.compressedText,
          useKey!,
        );
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;
      case EncryptionMethod.aesGcm:
        Map<String, String> encMap = Aes.encryptAesGcm(
          qrypt.compressedText,
          useKey!,
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
            StringBuffer hexBuffer = StringBuffer();
            for (var byte in rsaBytes) {
              hexBuffer.write(byte.toRadixString(16).padLeft(2, '0'));
            }
            qrypt.text = hexBuffer.toString();
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

          //sign the data
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

          // encrypt the entire package using hybrid encryption
          Map<String, String> encryptedPackage = await rsa.encryptLargeData(
            packageJson,
            qrypt.rsaReceiverPublicKey,
          );

          // Combine the encrypted package into a single string
          String encryptedResult =
              '${encryptedPackage['encryptedData']}:${encryptedPackage['encryptedKey']}:${encryptedPackage['iv']}';

          // Convert RSA result to appropriate format for obfuscation
          if (usesMappedObfuscation) {
            Uint8List rsaBytes = utf8.encode(encryptedResult);
            StringBuffer hexBuffer = StringBuffer();
            for (var byte in rsaBytes) {
              hexBuffer.write(byte.toRadixString(16).padLeft(2, '0'));
            }
            qrypt.text = hexBuffer.toString();
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
      case EncryptionMethod.mlKem:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Qrypt handleSign(Qrypt qrypt) {
    switch (qrypt.getSignMethod()) {
      case SignMethod.none:
        return qrypt;
      case SignMethod.mlDsa:
        MlDsaKeyService dsa = MlDsaKeyService();

        // Determine the format based on obfuscation method
        bool usesMappedObfuscation = [
          ObfuscationMethod.en1,
          ObfuscationMethod.en2,
          ObfuscationMethod.fa1,
          ObfuscationMethod.fa2,
        ].contains(qrypt.getObfuscationMethod());

        bool usesBase64Obfuscation =
            qrypt.getObfuscationMethod() == ObfuscationMethod.b64;

        Uint8List originalMessage;

        // Extract the original message based on current format
        // Note: At this point, qrypt.text contains the encrypted data in string format
        // For AES: "ciphertext:iv" format
        // For no encryption with mapped obfuscation: hex string

        if (qrypt.getEncryptionMethod() == EncryptionMethod.none) {
          // Only for no encryption case, handle format conversion
          if (qrypt.getObfuscationMethod() == ObfuscationMethod.none) {
            originalMessage = utf8.encode(qrypt.text);
          } else if (usesMappedObfuscation) {
            // Convert hex string back to bytes
            List<int> bytes = [];
            try {
              for (int i = 0; i < qrypt.text.length; i += 2) {
                String hexByte = qrypt.text.substring(i, i + 2);
                bytes.add(int.parse(hexByte, radix: 16));
              }
            } catch (e) {
              if (kDebugMode) {
                print('Hex parsing error in sign: $e');
              }
              throw FormatException('Invalid hex format for signing');
            }
            originalMessage = Uint8List.fromList(bytes);
          } else if (usesBase64Obfuscation) {
            // Convert string back to bytes
            originalMessage = Uint8List.fromList(qrypt.text.codeUnits);
          } else {
            // Decode base64 to get original bytes
            originalMessage = base64Decode(qrypt.text);
          }
        } else {
          // For encrypted data (AES, RSA, etc.), the text is already in the correct format
          // Just convert the string to bytes for signing
          try {
            originalMessage = utf8.encode(qrypt.text);
          } catch (e) {
            if (kDebugMode) {
              print('UTF8 encode error in sign: $e');
            }
            throw Exception('Invalid data for signing');
          }
        }

        // Sign the original message
        Uint8List signature = dsa.signMessage(
          originalMessage,
          qrypt.dsaKeyPair!.secretKey,
        );

        // Create signed package
        Map<String, String> signedPackage = {
          'message': base64Encode(originalMessage),
          'signature': base64Encode(signature),
        };

        // Encode the signed package and convert to appropriate format
        String signedPackageJson = jsonEncode(signedPackage);
        Uint8List signedPackageBytes = utf8.encode(signedPackageJson);

        // Format according to obfuscation method
        if (usesMappedObfuscation) {
          // Convert to hex for mapped obfuscations
          StringBuffer hexBuffer = StringBuffer();
          for (var byte in signedPackageBytes) {
            hexBuffer.write(byte.toRadixString(16).padLeft(2, '0'));
          }
          qrypt.text = hexBuffer.toString();

          if (kDebugMode) {
            print(
              'DSA Sign - Generated hex string length: ${qrypt.text.length}',
            );
            print(
              'DSA Sign - Encryption method: ${qrypt.getEncryptionMethod()}',
            );
          }

          // Verify the hex string has even length (should always be true)
          if (qrypt.text.length % 2 != 0) {
            if (kDebugMode) {
              print(
                'Warning: Generated hex string has odd length: ${qrypt.text.length}',
              );
            }
            // Pad with leading zero if odd
            qrypt.text = '0${qrypt.text}';
          }
        } else if (usesBase64Obfuscation) {
          // Keep as raw string for b64 obfuscation
          qrypt.text = String.fromCharCodes(signedPackageBytes);
        } else {
          // Use base64 for other obfuscations
          qrypt.text = base64Encode(signedPackageBytes);
        }

        return qrypt;
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
        obfsText = Obfuscate.obfuscateXOR(
          qrypt.text,
          42,
        ); // TODO: Consider random key for better security
        qrypt.text = obfsText;
        return qrypt;
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
    }
  }

  Qrypt handleVerify(Qrypt qrypt, BuildContext context) {
    switch (qrypt.getSignMethod()) {
      case SignMethod.none:
        return qrypt;
      case SignMethod.mlDsa:
        MlDsaKeyService dsa = MlDsaKeyService();

        try {
          // CHECK: Ensure public key is available before verification
          if (qrypt.dsaVerifyPublicKEy == null ||
              qrypt.dsaVerifyPublicKEy!.isEmpty) {
            throw const FormatException(
              'ML-DSA public key is required for signature verification.',
            );
          }

          // Determine format and decode accordingly
          bool usesMappedObfuscation = [
            ObfuscationMethod.en1,
            ObfuscationMethod.en2,
            ObfuscationMethod.fa1,
            ObfuscationMethod.fa2,
          ].contains(qrypt.getObfuscationMethod());

          bool usesBase64Obfuscation =
              qrypt.getObfuscationMethod() == ObfuscationMethod.b64;

          String packageJson;

          if (usesMappedObfuscation) {
            // Convert hex back to bytes then to string
            String hexString = qrypt.text;

            if (kDebugMode) {
              print(
                'DSA Verify - Original hex string length: ${hexString.length}',
              );
              print(
                'DSA Verify - Hex string preview: ${hexString.length > 100 ? "${hexString.substring(0, 100)}..." : hexString}',
              );
            }

            // Ensure hex string has even length
            if (hexString.length % 2 != 0) {
              if (kDebugMode) {
                print(
                  'DSA Verify - ERROR: Hex string has odd length: ${hexString.length}',
                );
                print(
                  'DSA Verify - Last 50 chars: ${hexString.substring(hexString.length - 50)}',
                );
              }
              throw FormatException(
                'Invalid hex string length: ${hexString.length}. Hex strings must have even length.',
              );
            }

            List<int> bytes = [];
            try {
              for (int i = 0; i < hexString.length; i += 2) {
                String hexByte = hexString.substring(i, i + 2);
                bytes.add(int.parse(hexByte, radix: 16));
              }
              packageJson = utf8.decode(bytes);
            } catch (e) {
              if (kDebugMode) {
                print('Hex parsing or UTF8 decode error in verify: $e');
              }
              throw FormatException('Invalid format in verification: $e');
            }
          } else if (usesBase64Obfuscation) {
            // Convert string back to bytes then decode
            try {
              packageJson = utf8.decode(qrypt.text.codeUnits);
            } catch (e) {
              if (kDebugMode) {
                print('UTF8 decode error in verify (base64): $e');
              }
              throw Exception('Invalid data in verification');
            }
          } else {
            // Decode base64 then convert to string
            try {
              packageJson = utf8.decode(base64Decode(qrypt.text));
            } catch (e) {
              if (kDebugMode) {
                print('Base64 or UTF8 decode error in verify: $e');
              }
              throw Exception('Invalid data in verification');
            }
          }

          // Parse the signed package
          Map<String, dynamic> signedPackage = jsonDecode(packageJson);

          // Extract message and signature
          Uint8List originalMessage = base64Decode(signedPackage['message']);
          Uint8List signature = base64Decode(signedPackage['signature']);

          if (kDebugMode) {
            print(
              'DSA Verify - Original message length: ${originalMessage.length}',
            );
            print(
              'DSA Verify - Original message preview: ${originalMessage.take(50).map((b) => b.toRadixString(16).padLeft(2, '0')).join('')}',
            );

            // Try to decode as string to see if it's text data
            try {
              String messageAsString = utf8.decode(originalMessage);
              print(
                'DSA Verify - Message as string preview: ${messageAsString.length > 100 ? "${messageAsString.substring(0, 100)}..." : messageAsString}',
              );
            } catch (e) {
              print(
                'DSA Verify - Message is not valid UTF-8 text (likely binary data)',
              );
            }
          }

          // Verify the signature - now safe to use ! operator
          bool isValid = dsa.verifySignature(
            originalMessage, // The original message
            signature, // The signature
            qrypt.dsaVerifyPublicKEy!, // The public key for verification
          );

          if (!isValid) {
            throw const FormatException(
              'ML-DSA signature verification failed. Message may have been altered or forged.',
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('DSA signature verification successful ✓'),
              backgroundColor: Colors.green,
            ),
          );
          if (kDebugMode) {
            print('DSA signature verification successful ✓');
          }

          // Return the original message - this should be the encrypted data (like "ciphertext:iv")
          // or compressed binary data for encryption.none
          if (qrypt.getEncryptionMethod() == EncryptionMethod.none) {
            // For no encryption, the original message is compressed binary data
            // We need to set it in qrypt.deCompressedText for decompression to work
            qrypt.deCompressedText = originalMessage;
            // Set a placeholder text that won't be used
            qrypt.text = "BINARY_DATA_PLACEHOLDER";

            if (kDebugMode) {
              print(
                'DSA Verify - Set binary data for decompression, length: ${originalMessage.length}',
              );
            }
          } else {
            // For encrypted data, convert back to string format for further processing
            try {
              String originalDataString = utf8.decode(originalMessage);
              qrypt.text = originalDataString;

              if (kDebugMode) {
                print(
                  'DSA Verify - Set encrypted data string: ${originalDataString.length > 50 ? "${originalDataString.substring(0, 50)}..." : originalDataString}',
                );
              }
            } catch (e) {
              if (kDebugMode) {
                print(
                  'DSA Verify - Failed to decode as UTF-8, treating as binary: $e',
                );
              }
              // If it fails to decode as UTF-8, treat as binary
              qrypt.deCompressedText = originalMessage;
              qrypt.text = "BINARY_DATA_PLACEHOLDER";
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during DSA verification: $e'),
              backgroundColor: Colors.red,
            ),
          );
          if (kDebugMode) {
            print('Error during DSA verification: $e');
          }
          throw Exception('DSA verification failed: $e');
        }

        return qrypt;
    }
  }

  Future<Qrypt> handleDecrypt(Qrypt qrypt, [BuildContext? buildContext]) async {
    if (qrypt.text == "BINARY_DATA_PLACEHOLDER") {
      if (kDebugMode) {
        print(
          'Decrypt - Using data from DSA verification, length: ${qrypt.deCompressedText.length}',
        );
      }
      return qrypt; // Skip decryption as data is already decompressed
    }

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
          try {
            for (int i = 0; i < qrypt.text.length; i += 2) {
              String hexByte = qrypt.text.substring(i, i + 2);
              bytes.add(int.parse(hexByte, radix: 16));
            }
          } catch (e) {
            if (kDebugMode) {
              print('Hex parsing error in decrypt: $e');
            }
            throw FormatException('Invalid hex format in decryption');
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

        // STEP 1: Direct decryption if a key was already supplied
        if (qrypt.useCustomKey &&
            qrypt.customKey.isNotEmpty &&
            qrypt.customKey != 'noCustomKey') {
          final decryptKey = encrypt.Key.fromUtf8(qrypt.customKey);
          final decryptedData = _decryptWithAESKey(
            qrypt.getEncryptionMethod(),
            parts[0],
            parts[1],
            decryptKey,
          );

          if (decryptedData != null) {
            qrypt.deCompressedText = decryptedData;
            return qrypt;
          }

          // For CBC/CTR (which cannot verify authentication tags), throw immediately.
          // For AES-GCM, fall through to trial-decryption against saved keys (Step 2)
          // or user prompt dialog (Step 3) in case the pre-selected key was wrong.
          if (qrypt.getEncryptionMethod() != EncryptionMethod.aesGcm) {
            throw Exception('AES decryption failed: invalid key');
          }
        }

        // STEP 2: Key was not provided.
        // For AES-GCM (AEAD), trial-decrypt against saved keys (last-used first)
        if (qrypt.getEncryptionMethod() == EncryptionMethod.aesGcm) {
          try {
            final storage = const AesKeyStorageService();
            final savedKeys = await storage.getKeys();
            final lastUsedId = await storage.getLastUsedKeyId();

            if (lastUsedId != null) {
              final lastIdx = savedKeys.indexWhere((k) => k.id == lastUsedId);
              if (lastIdx > 0) {
                final lastKey = savedKeys.removeAt(lastIdx);
                savedKeys.insert(0, lastKey);
              }
            }

            for (final savedKey in savedKeys) {
              try {
                final decryptedData = _decryptWithAESKey(
                  EncryptionMethod.aesGcm,
                  parts[0],
                  parts[1],
                  encrypt.Key.fromUtf8(savedKey.key),
                );
                if (decryptedData != null) {
                  qrypt.deCompressedText = decryptedData;
                  qrypt.customKey = savedKey.key;
                  qrypt.useCustomKey = true;
                  if (kDebugMode) {
                    print(
                      '✓ Decryption successful with saved key: ${savedKey.name}',
                    );
                  }
                  return qrypt;
                }
              } catch (_) {
                // Ignore trial decryption error on GCM
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                'Trial decryption against saved keys encountered error: $e',
              );
            }
          }
        }

        // STEP 3: Prompt user for key if context is available
        if (buildContext != null && buildContext.mounted) {
          final enteredKey = await _showCustomKeyDialog(buildContext);
          if (enteredKey != null && enteredKey.isNotEmpty) {
            final customEncryptKey = encrypt.Key.fromUtf8(enteredKey);
            final decryptedData = _decryptWithAESKey(
              qrypt.getEncryptionMethod(),
              parts[0],
              parts[1],
              customEncryptKey,
            );

            if (decryptedData != null) {
              qrypt.deCompressedText = decryptedData;
              qrypt.customKey = enteredKey;
              qrypt.useCustomKey = true;
              return qrypt;
            } else {
              throw Exception(
                'Decryption failed: invalid key or authentication mismatch. '
                '(If this ciphertext was encrypted with Qrypt v4\'s default key, please use a v4.x release).',
              );
            }
          } else {
            throw const MissingKeyException(
              'Decryption cancelled: no AES key was provided.',
            );
          }
        } else {
          throw const MissingKeyException(
            'An AES key is required for decryption. Please select or supply a key.',
          );
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
            try {
              for (int i = 0; i < qrypt.text.length; i += 2) {
                String hexByte = qrypt.text.substring(i, i + 2);
                bytes.add(int.parse(hexByte, radix: 16));
              }
            } catch (e) {
              if (kDebugMode) {
                print('Hex parsing error in RSA decrypt: $e');
              }
              throw FormatException('Invalid hex format in RSA decryption');
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
            try {
              for (int i = 0; i < qrypt.text.length; i += 2) {
                String hexByte = qrypt.text.substring(i, i + 2);
                bytes.add(int.parse(hexByte, radix: 16));
              }
              rsaInputText = utf8.decode(bytes);
            } catch (e) {
              if (kDebugMode) {
                print(
                  'Hex parsing or UTF8 decode error in RSA+Sign decrypt: $e',
                );
              }
              throw FormatException(
                'Invalid format in RSA+Sign decryption: $e',
              );
            }
          } else if (usesBase64Obfuscation) {
            rsaInputText = qrypt.text;
          } else {
            try {
              rsaInputText = utf8.decode(base64.decode(qrypt.text));
            } catch (e) {
              if (kDebugMode) {
                print('Base64 or UTF8 decode error in RSA+Sign decrypt: $e');
              }
              throw Exception('Invalid data in RSA+Sign decryption');
            }
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
            if (buildContext != null && buildContext.mounted) {
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
            if (buildContext != null && buildContext.mounted) {
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
      case EncryptionMethod.mlKem:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Qrypt handleDeCompression(Qrypt qrypt) {
    switch (qrypt.getCompressionMethod()) {
      case CompressionMethod.none:
        try {
          qrypt.text = utf8.decode(qrypt.deCompressedText);
        } catch (e) {
          if (kDebugMode) {
            print('UTF8 decode error in decompression: $e');
          }
          qrypt.text = ''; // Fallback to empty on error
        }
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

    if (qrypt.getSignMethod() != SignMethod.none) {
      qrypt = handleSign(qrypt);
    }
    qrypt.text = qrypt.tag + qrypt.text;
    qrypt = handleObfs(qrypt);
    return qrypt;
  }

  Future<Qrypt> handleDeProcess(
    BuildContext? context,
    Qrypt qrypt,
    bool useTag,
  ) async {
    Color primaryColor = Colors.blue;
    if (!useTag) {
      qrypt = handleDeObfs(qrypt);
      if (qrypt.getSignMethod() != SignMethod.none && context != null) {
        qrypt = handleVerify(qrypt, context);
      }
      qrypt = await handleDecrypt(qrypt, context);
      qrypt = handleDeCompression(qrypt);
    } else {
      String? tag = TagManager.matchedTag(qrypt.text);
      if (tag == null) {
        throw FormatException(
          'Invalid tag format',
        ); // Changed to throw for better error handling
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
        qrypt.sign = methods.sign;
        qrypt = handleDeObfs(qrypt);
        if (qrypt.sign == SignMethod.mlDsa) {
          if (context == null) {
            throw Exception(
              'Decryption cancelled: No context to select ML-DSA key',
            );
          }
          String? dsaSenderPublicKey = await showMlDsaPublicKeyInputDialog(
            context: context,
            primaryColor: primaryColor,
            title: 'Select Verification Key',
            message:
                'This content was signed with DSA. Please select the appropriate key pair for verification.',
          );
          if (dsaSenderPublicKey == null) {
            throw Exception('Decryption cancelled: No key pair selected');
          }
          qrypt.dsaVerifyPublicKEy = base64Decode(dsaSenderPublicKey);
        }
        if (context != null && !context.mounted) return qrypt;
        if (context != null) {
          qrypt = handleVerify(qrypt, context);
        }
        if (qrypt.encryption == EncryptionMethod.rsa ||
            qrypt.encryption == EncryptionMethod.rsaSign) {
          if (context == null) {
            throw Exception(
              'Decryption cancelled: No context to select RSA key',
            );
          }
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
        if (context != null && !context.mounted) return qrypt;
        qrypt = await handleDecrypt(qrypt, context);
        qrypt = handleDeCompression(qrypt);
      }
    }
    return qrypt;
  }

  Future<Qrypt> handleKemProcess(Qrypt krypt, String publicKey) async {
    KemKeyService kem = KemKeyService();
    Uint8List uint8PublicKey = base64Decode(publicKey);
    KEMEncapsulationResult encResult = kem.encapsulateWithPublicKey(
      uint8PublicKey,
    );
    Qrypt qrypt = Qrypt.forKem(
      ciphertext: encResult.ciphertext,
      kemSharedSecret: encResult.sharedSecret,
    );
    return qrypt;
  }

  Future<Qrypt> handleKemDeProcess(Qrypt krypt, QryptKEMKeyPair keyPair) async {
    KemKeyService kem = KemKeyService();
    Uint8List uint8Ciphertext = base64Decode(krypt.inputCiphertext);
    debugPrint(keyPair.secretKey.length.toString());
    Uint8List sharedSecret = kem.decapsulateWithSecretKey(
      uint8Ciphertext,
      keyPair.secretKey,
    );

    Qrypt qrypt = Qrypt.forKemDecrypt(kemSharedSecret: sharedSecret);
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
      if (kDebugMode) {
        print('Attempting AES decryption with method: $method');
        print('Ciphertext length: ${ciphertext.length}');
        print('IV length: ${iv.length}');
      }

      switch (method) {
        case EncryptionMethod.aesCbc:
          final result = Aes.decryptAesCbc(ciphertext, iv, key);
          // Convert List<int> to Uint8List if needed
          if (result is! Uint8List) {
            return Uint8List.fromList(result);
          }
          return result;

        case EncryptionMethod.aesCtr:
          final result = Aes.decryptAesCtr(ciphertext, iv, key);
          // Convert List<int> to Uint8List if needed
          if (result is! Uint8List) {
            return Uint8List.fromList(result);
          }
          return result;

        case EncryptionMethod.aesGcm:
          final result = Aes.decryptAesGcm(ciphertext, iv, key);
          if (result == null) {
            if (kDebugMode) {
              print(
                'AES-GCM decryption returned null - likely authentication failure',
              );
            }
            return null;
          }
          // Convert List<int> to Uint8List if needed
          if (result is! Uint8List) {
            return Uint8List.fromList(result);
          }
          return result;

        default:
          if (kDebugMode) {
            print('Invalid AES encryption method: $method');
          }
          throw Exception('Invalid AES encryption method: $method');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AES decryption error with method $method: $e');
      }
      // Return null on any decryption error to trigger custom key prompt
      return null;
    }
  }

  Future<String?> _showCustomKeyDialog(BuildContext context) async {
    final TextEditingController keyController = TextEditingController();
    String? errorText;
    final List<AESKey> savedKeys = await const AesKeyStorageService().getKeys();
    if (!context.mounted) return null;
    AESKey? selectedSavedKey;

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.key, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text('AES Key Required'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'An AES key is required to decrypt this content. Select a saved key or enter one manually.\n\nNote: Messages encrypted with Qrypt v4\'s built-in default key cannot be decrypted in v5+. Please use a v4.x release for those messages.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      if (savedKeys.isNotEmpty) ...[
                        DropdownButtonFormField<AESKey>(
                          initialValue: selectedSavedKey,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Choose Saved Key',
                            prefixIcon: Icon(Icons.bookmark_outline),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          hint: const Text('Select a saved key...'),
                          items: savedKeys.map((k) {
                            return DropdownMenuItem<AESKey>(
                              value: k,
                              child: Text('${k.name} (${k.bitLength}-bit)'),
                            );
                          }).toList(),
                          onChanged: (k) {
                            if (k != null) {
                              setState(() {
                                selectedSavedKey = k;
                                keyController.text = k.key;
                                errorText = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'OR ENTER MANUALLY',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: keyController,
                        decoration: InputDecoration(
                          labelText: 'Enter Custom AES Key',
                          hintText: '16, 24, or 32 bytes (characters if ASCII)',
                          prefixIcon: const Icon(Icons.vpn_key),
                          border: const OutlineInputBorder(),
                          errorText: errorText,
                          helperText:
                              'Current byte length: ${utf8.encode(keyController.text).length}',
                        ),
                        obscureText: true, // Obscure input for security
                        maxLines: 1,
                        autofocus: savedKeys.isEmpty,
                        onChanged: (value) {
                          setState(() {
                            final byteLength = utf8
                                .encode(value)
                                .length; // Check byte length
                            if (value.isNotEmpty &&
                                byteLength != 16 &&
                                byteLength != 24 &&
                                byteLength != 32) {
                              errorText =
                                  'Key must be exactly 16, 24, or 32 bytes';
                            } else {
                              errorText = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• AES-128: 16 bytes\n• AES-192: 24 bytes\n• AES-256: 32 bytes',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: errorText != null || keyController.text.isEmpty
                      ? null
                      : () {
                          final key = keyController.text.trim();
                          final byteLength = utf8.encode(key).length;
                          if (byteLength == 16 ||
                              byteLength == 24 ||
                              byteLength == 32) {
                            Navigator.of(context).pop(key);
                          }
                        },
                  child: const Text('Decrypt'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
