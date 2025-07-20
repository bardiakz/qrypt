import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:asn1lib/asn1lib.dart' as asn1lib;

import '../../models/rsa_key_pair.dart';
import 'rsa_key_storage_service.dart';

class RSAKeyService {
  final RSAKeyStorageService _storageService;

  // Constructor with dependency injection for storage service
  RSAKeyService({RSAKeyStorageService? storageService})
    : _storageService = storageService ?? RSAKeyStorageService();

  // Delegate storage operations to the storage service
  Future<List<RSAKeyPair>> getKeyPairs() => _storageService.getKeyPairs();
  Future<void> saveKeyPair(RSAKeyPair keyPair) =>
      _storageService.saveKeyPair(keyPair);
  Future<void> deleteKeyPair(String id) => _storageService.deleteKeyPair(id);
  Future<void> updateKeyPair(RSAKeyPair updatedKeyPair) =>
      _storageService.updateKeyPair(updatedKeyPair);
  Future<RSAKeyPair?> getKeyPairById(String id) =>
      _storageService.getKeyPairById(id);
  Future<void> clearAllKeyPairs() => _storageService.clearAllKeyPairs();

  // Additional storage convenience methods
  Future<bool> keyPairExists(String id) => _storageService.keyPairExists(id);
  Future<int> getKeyPairsCount() => _storageService.getKeyPairsCount();
  Future<bool> keyPairNameExists(String name) =>
      _storageService.keyPairNameExists(name);
  Future<List<RSAKeyPair>> searchKeyPairsByName(String searchTerm) =>
      _storageService.searchKeyPairsByName(searchTerm);

  /// Generates a new RSA key pair with the specified name and key size
  Future<RSAKeyPair> generateKeyPair(String name, {int keySize = 2048}) async {
    try {
      // Check if name already exists
      if (await keyPairNameExists(name)) {
        throw Exception('A key pair with the name "$name" already exists');
      }

      // Generate RSA key pair using pointycastle
      final keyGen = RSAKeyGenerator();
      final secureRandom = _getSecureRandom();

      keyGen.init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), keySize, 64),
          secureRandom,
        ),
      );

      final pair = keyGen.generateKeyPair();
      final publicKey = pair.publicKey as RSAPublicKey;
      final privateKey = pair.privateKey as RSAPrivateKey;

      // Convert to PEM format
      final publicKeyPem = _encodePublicKeyToPem(publicKey);
      final privateKeyPem = _encodePrivateKeyToPem(privateKey);

      final keyPair = RSAKeyPair(
        id: const Uuid().v4(),
        name: name,
        publicKey: publicKeyPem,
        privateKey: privateKeyPem,
        createdAt: DateTime.now(),
      );

      await saveKeyPair(keyPair);
      return keyPair;
    } catch (e) {
      print('Error generating key pair: $e');
      rethrow;
    }
  }

  /// Imports an existing RSA key pair from PEM strings
  Future<RSAKeyPair> importKeyPair({
    required String name,
    required String publicKeyPem,
    required String privateKeyPem,
  }) async {
    try {
      // Check if name already exists
      if (await keyPairNameExists(name)) {
        throw Exception('A key pair with the name "$name" already exists');
      }

      if (!validateKeyPair(publicKeyPem, privateKeyPem)) {
        throw Exception('Invalid key pair - keys do not match');
      }

      final keyPair = RSAKeyPair(
        id: const Uuid().v4(),
        name: name,
        publicKey: publicKeyPem.trim(),
        privateKey: privateKeyPem.trim(),
        createdAt: DateTime.now(),
      );

      await saveKeyPair(keyPair);
      return keyPair;
    } catch (e) {
      print('Error importing key pair: $e');
      rethrow;
    }
  }

  /// Validates that a public and private key pair match
  bool validateKeyPair(String publicKeyPem, String privateKeyPem) {
    try {
      final publicKey = _parsePublicKey(publicKeyPem);
      final privateKey = _parsePrivateKey(privateKeyPem);

      if (publicKey == null || privateKey == null) {
        return false;
      }

      // Test encryption/decryption to validate the key pair
      final plaintext = 'test message';
      final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

      // Encrypt with public key
      final encryptor = OAEPEncoding(RSAEngine());
      encryptor.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
      final encrypted = encryptor.process(plaintextBytes);

      // Decrypt with private key
      final decryptor = OAEPEncoding(RSAEngine());
      decryptor.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
      final decrypted = decryptor.process(encrypted);

      final decryptedText = utf8.decode(decrypted);
      return decryptedText == plaintext;
    } catch (e) {
      print('Key validation error: $e');
      return false;
    }
  }

  /// Encrypts plaintext using the public key
  Future<String> encryptWithPublicKey(
    String plaintext,
    String publicKeyPem,
  ) async {
    try {
      final publicKey = _parsePublicKey(publicKeyPem);
      if (publicKey == null) {
        throw Exception('Invalid public key format');
      }

      final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
      final encryptor = OAEPEncoding(RSAEngine());
      encryptor.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
      final encrypted = encryptor.process(plaintextBytes);
      return base64.encode(encrypted);
    } catch (e) {
      print('Encryption error: $e');
      rethrow;
    }
  }

  /// Encrypts plaintext using a stored key pair's public key
  Future<String> encryptWithStoredPublicKey(
    String plaintext,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return await encryptWithPublicKey(plaintext, keyPair.publicKey);
    } catch (e) {
      print('Encryption with stored key error: $e');
      rethrow;
    }
  }

  /// Decrypts ciphertext using the private key
  Future<String> decryptWithPrivateKey(
    String ciphertext,
    String privateKeyPem,
  ) async {
    try {
      final privateKey = _parsePrivateKey(privateKeyPem);
      if (privateKey == null) {
        throw Exception('Invalid private key format');
      }

      final ciphertextBytes = base64.decode(ciphertext);
      final decryptor = OAEPEncoding(RSAEngine());
      decryptor.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
      final decrypted = decryptor.process(ciphertextBytes);
      return utf8.decode(decrypted);
    } catch (e) {
      print('Decryption error: $e');
      rethrow;
    }
  }

  /// Decrypts ciphertext using a stored key pair's private key
  Future<String> decryptWithStoredPrivateKey(
    String ciphertext,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return await decryptWithPrivateKey(ciphertext, keyPair.privateKey);
    } catch (e) {
      print('Decryption with stored key error: $e');
      rethrow;
    }
  }

  /// Signs a message using the private key
  Future<String> signWithPrivateKey(
    String message,
    String privateKeyPem,
  ) async {
    try {
      final privateKey = _parsePrivateKey(privateKeyPem);
      if (privateKey == null) {
        throw Exception('Invalid private key format');
      }

      final messageBytes = Uint8List.fromList(utf8.encode(message));

      // Create PKCS1 signer with SHA-256
      final signer = Signer('SHA-256/RSA');
      signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
      final signature = signer.generateSignature(messageBytes) as RSASignature;

      return base64.encode(signature.bytes);
    } catch (e) {
      print('Signing error: $e');
      rethrow;
    }
  }

  /// Signs a message using a stored key pair's private key
  Future<String> signWithStoredPrivateKey(
    String message,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return await signWithPrivateKey(message, keyPair.privateKey);
    } catch (e) {
      print('Signing with stored key error: $e');
      rethrow;
    }
  }

  /// Verifies a message signature using the public key
  Future<bool> verifyWithPublicKey(
    String message,
    String signature,
    String publicKeyPem,
  ) async {
    try {
      final publicKey = _parsePublicKey(publicKeyPem);
      if (publicKey == null) {
        return false;
      }

      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final signatureBytes = base64.decode(signature);

      // Create PKCS1 verifier with SHA-256
      final verifier = Signer('SHA-256/RSA');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      final rsaSignature = RSASignature(signatureBytes);
      return verifier.verifySignature(messageBytes, rsaSignature);
    } catch (e) {
      print('Verification error: $e');
      return false;
    }
  }

  /// Verifies a message signature using a stored key pair's public key
  Future<bool> verifyWithStoredPublicKey(
    String message,
    String signature,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        return false;
      }
      return await verifyWithPublicKey(message, signature, keyPair.publicKey);
    } catch (e) {
      print('Verification with stored key error: $e');
      return false;
    }
  }

  /// Gets the key size in bits for a given public key
  int getKeySize(String publicKeyPem) {
    try {
      final publicKey = _parsePublicKey(publicKeyPem);
      if (publicKey == null) {
        throw Exception('Invalid public key format');
      }
      return publicKey.modulus!.bitLength;
    } catch (e) {
      print('Error getting key size: $e');
      rethrow;
    }
  }

  /// Gets the key size for a stored key pair
  Future<int> getStoredKeySize(String keyPairId) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return getKeySize(keyPair.publicKey);
    } catch (e) {
      print('Error getting stored key size: $e');
      rethrow;
    }
  }

  // Private helper methods for cryptographic operations

  SecureRandom _getSecureRandom() {
    final secureRandom = SecureRandom('Fortuna')
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List.generate(32, (i) => Random.secure().nextInt(256)),
          ),
        ),
      );
    return secureRandom;
  }

  String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    var algorithmSeq = asn1lib.ASN1Sequence();
    var algorithmAsn1Obj = asn1lib.ASN1Object.fromBytes(
      Uint8List.fromList([
        0x6,
        0x9,
        0x2a,
        0x86,
        0x48,
        0x86,
        0xf7,
        0xd,
        0x1,
        0x1,
        0x1,
      ]),
    );
    var paramsAsn1Obj = asn1lib.ASN1Object.fromBytes(
      Uint8List.fromList([0x5, 0x0]),
    );
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    var publicKeySeq = asn1lib.ASN1Sequence();
    publicKeySeq.add(asn1lib.ASN1Integer(publicKey.modulus!));
    publicKeySeq.add(asn1lib.ASN1Integer(publicKey.exponent!));
    var publicKeySeqBitString = asn1lib.ASN1BitString(
      publicKeySeq.encodedBytes,
    );

    var topLevelSeq = asn1lib.ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeySeqBitString);

    var dataBase64 = base64.encode(topLevelSeq.encodedBytes);
    var chunks = <String>[];
    for (var i = 0; i < dataBase64.length; i += 64) {
      var end = (i + 64 < dataBase64.length) ? i + 64 : dataBase64.length;
      chunks.add(dataBase64.substring(i, end));
    }

    return "-----BEGIN PUBLIC KEY-----\n${chunks.join('\n')}\n-----END PUBLIC KEY-----";
  }

  String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    // Create PKCS#8 PrivateKeyInfo structure
    var version = asn1lib.ASN1Integer(BigInt.from(0));

    // Algorithm identifier for RSA
    var algorithmSeq = asn1lib.ASN1Sequence();
    var algorithmAsn1Obj = asn1lib.ASN1Object.fromBytes(
      Uint8List.fromList([
        0x6,
        0x9,
        0x2a,
        0x86,
        0x48,
        0x86,
        0xf7,
        0xd,
        0x1,
        0x1,
        0x1,
      ]),
    );
    var paramsAsn1Obj = asn1lib.ASN1Object.fromBytes(
      Uint8List.fromList([0x5, 0x0]),
    );
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    // Create the RSA private key structure (PKCS#1)
    var rsaPrivateKeySeq = asn1lib.ASN1Sequence();
    rsaPrivateKeySeq.add(asn1lib.ASN1Integer(BigInt.from(0))); // version
    rsaPrivateKeySeq.add(asn1lib.ASN1Integer(privateKey.n!)); // modulus
    rsaPrivateKeySeq.add(
      asn1lib.ASN1Integer(privateKey.exponent!),
    ); // publicExponent
    rsaPrivateKeySeq.add(asn1lib.ASN1Integer(privateKey.d!)); // privateExponent
    rsaPrivateKeySeq.add(asn1lib.ASN1Integer(privateKey.p!)); // prime1
    rsaPrivateKeySeq.add(asn1lib.ASN1Integer(privateKey.q!)); // prime2

    var dP = privateKey.d! % (privateKey.p! - BigInt.one);
    var dQ = privateKey.d! % (privateKey.q! - BigInt.one);
    var qInv = privateKey.q!.modInverse(privateKey.p!);

    rsaPrivateKeySeq.add(asn1lib.ASN1Integer(dP)); // exponent1
    rsaPrivateKeySeq.add(asn1lib.ASN1Integer(dQ)); // exponent2
    rsaPrivateKeySeq.add(asn1lib.ASN1Integer(qInv)); // coefficient

    // Wrap in PKCS#8 structure
    var privateKeyInfo = asn1lib.ASN1Sequence();
    privateKeyInfo.add(version);
    privateKeyInfo.add(algorithmSeq);
    privateKeyInfo.add(asn1lib.ASN1OctetString(rsaPrivateKeySeq.encodedBytes));

    var dataBase64 = base64.encode(privateKeyInfo.encodedBytes);
    var chunks = <String>[];
    for (var i = 0; i < dataBase64.length; i += 64) {
      var end = (i + 64 < dataBase64.length) ? i + 64 : dataBase64.length;
      chunks.add(dataBase64.substring(i, end));
    }

    return "-----BEGIN PRIVATE KEY-----\n${chunks.join('\n')}\n-----END PRIVATE KEY-----";
  }

  // RSAPublicKey? _parsePublicKey(String pemString) {
  //   try {
  //     final publicKeyDER = _decodePEM(pemString);
  //     if (publicKeyDER.isEmpty) {
  //       print('Empty DER data after PEM decoding');
  //       return null;
  //     }
  //
  //     var asn1Parser = asn1lib.ASN1Parser(publicKeyDER);
  //     var topLevelSeq = asn1Parser.nextObject();
  //
  //     if (topLevelSeq is! asn1lib.ASN1Sequence) {
  //       print('Top level object is not an ASN1Sequence');
  //       return null;
  //     }
  //
  //     // Handle both PKCS#8 SubjectPublicKeyInfo and raw PKCS#1 formats
  //     if (topLevelSeq.elements.length == 2) {
  //       // PKCS#8 SubjectPublicKeyInfo format
  //       var algorithmSeq = topLevelSeq.elements[0];
  //       var publicKeyBitString = topLevelSeq.elements[1];
  //
  //       if (publicKeyBitString is! asn1lib.ASN1BitString) {
  //         print('Second element is not an ASN1BitString');
  //         return null;
  //       }
  //
  //       var publicKeyBytes = publicKeyBitString.valueBytes();
  //       if (publicKeyBytes == null || publicKeyBytes.isEmpty) {
  //         print('Empty public key bytes');
  //         return null;
  //       }
  //
  //       var publicKeyAsn = asn1lib.ASN1Parser(publicKeyBytes);
  //       var publicKeySeq = publicKeyAsn.nextObject();
  //
  //       if (publicKeySeq is! asn1lib.ASN1Sequence) {
  //         print('Public key sequence is not an ASN1Sequence');
  //         return null;
  //       }
  //
  //       if (publicKeySeq.elements.length < 2) {
  //         print('Public key sequence has insufficient elements');
  //         return null;
  //       }
  //
  //       var modulusElement = publicKeySeq.elements[0];
  //       var exponentElement = publicKeySeq.elements[1];
  //
  //       if (modulusElement is! asn1lib.ASN1Integer ||
  //           exponentElement is! asn1lib.ASN1Integer) {
  //         print('Modulus or exponent is not an ASN1Integer');
  //         return null;
  //       }
  //
  //       var modulus = modulusElement.valueAsBigInteger;
  //       var exponent = exponentElement.valueAsBigInteger;
  //
  //       if (modulus == null || exponent == null) {
  //         print('Null modulus or exponent');
  //         return null;
  //       }
  //
  //       return RSAPublicKey(modulus, exponent);
  //     } else if (topLevelSeq.elements.length >= 2) {
  //       // Try raw PKCS#1 RSAPublicKey format
  //       var modulusElement = topLevelSeq.elements[0];
  //       var exponentElement = topLevelSeq.elements[1];
  //
  //       if (modulusElement is! asn1lib.ASN1Integer ||
  //           exponentElement is! asn1lib.ASN1Integer) {
  //         print('Raw format: Modulus or exponent is not an ASN1Integer');
  //         return null;
  //       }
  //
  //       var modulus = modulusElement.valueAsBigInteger;
  //       var exponent = exponentElement.valueAsBigInteger;
  //
  //       if (modulus == null || exponent == null) {
  //         print('Raw format: Null modulus or exponent');
  //         return null;
  //       }
  //
  //       return RSAPublicKey(modulus, exponent);
  //     } else {
  //       print(
  //         'Unexpected number of elements in top level sequence: ${topLevelSeq.elements.length}',
  //       );
  //       return null;
  //     }
  //   } catch (e, stackTrace) {
  //     print('Error parsing public key: $e');
  //     print('Stack trace: $stackTrace');
  //     return null;
  //   }
  // }
  RSAPublicKey? _parsePublicKey(String pemString) {
    try {
      final publicKeyDER = _decodePEM(pemString);
      if (publicKeyDER.isEmpty) {
        print('Empty DER data after PEM decoding');
        return null;
      }

      var asn1Parser = asn1lib.ASN1Parser(publicKeyDER);
      var topLevelSeq = asn1Parser.nextObject();

      if (topLevelSeq is! asn1lib.ASN1Sequence ||
          topLevelSeq.elements.length != 2) {
        print('Invalid top-level sequence');
        return null;
      }

      var publicKeyBitString = topLevelSeq.elements[1];
      if (publicKeyBitString is! asn1lib.ASN1BitString) {
        print('Second element is not an ASN1BitString');
        return null;
      }

      var publicKeyBytes = publicKeyBitString.valueBytes();
      if (publicKeyBytes == null || publicKeyBytes.isEmpty) {
        print('Empty public key bytes');
        return null;
      }

      // Skip the unused bits byte if present and unusedbits is 0
      if (publicKeyBytes[0] == 0x00 && publicKeyBitString.unusedbits == 0) {
        publicKeyBytes = publicKeyBytes.sublist(1);
      }

      var parser = asn1lib.ASN1Parser(publicKeyBytes);
      var publicKeySeq = parser.nextObject();

      if (publicKeySeq is! asn1lib.ASN1Sequence ||
          publicKeySeq.elements.length < 2) {
        print('Invalid RSAPublicKey sequence');
        return null;
      }

      var modulusElement = publicKeySeq.elements[0];
      var exponentElement = publicKeySeq.elements[1];

      if (modulusElement is! asn1lib.ASN1Integer ||
          exponentElement is! asn1lib.ASN1Integer) {
        print('Modulus or exponent is not an ASN1Integer');
        return null;
      }

      var modulus = modulusElement.valueAsBigInteger;
      var exponent = exponentElement.valueAsBigInteger;

      if (modulus == null || exponent == null) {
        print('Null modulus or exponent');
        return null;
      }

      return RSAPublicKey(modulus, exponent);
    } catch (e, stackTrace) {
      print('Error parsing public key: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Uint8List _decodePEM(String pem) {
    try {
      if (pem.trim().isEmpty) {
        throw FormatException('Empty PEM string');
      }

      String normalizedPem = pem
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .trim();
      int startMarkerStart = normalizedPem.indexOf('-----BEGIN');
      if (startMarkerStart == -1) {
        throw FormatException('Invalid PEM format: missing BEGIN marker');
      }

      int startMarkerEnd = normalizedPem.indexOf('-----', startMarkerStart + 5);
      if (startMarkerEnd == -1) {
        throw FormatException('Invalid PEM format: malformed BEGIN marker');
      }

      int endMarkerStart = normalizedPem.indexOf('-----END');
      if (endMarkerStart == -1) {
        throw FormatException('Invalid PEM format: missing END marker');
      }

      String base64Content = normalizedPem
          .substring(startMarkerEnd + 5, endMarkerStart)
          .trim();
      base64Content = base64Content.replaceAll(RegExp(r'\s+'), '');

      if (base64Content.isEmpty) {
        throw FormatException('Invalid PEM format: empty content');
      }

      if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(base64Content)) {
        throw FormatException('Invalid PEM format: invalid base64 characters');
      }

      return base64.decode(base64Content);
    } catch (e) {
      print('PEM decode error: $e');
      rethrow;
    }
  }

  RSAPrivateKey? _parsePrivateKey(String pemString) {
    try {
      final privateKeyDER = _decodePEM(pemString);
      if (privateKeyDER.isEmpty) {
        print('Empty DER data after PEM decoding');
        return null;
      }

      var asn1Parser = asn1lib.ASN1Parser(privateKeyDER);
      var pkSeq = asn1Parser.nextObject();

      if (pkSeq is! asn1lib.ASN1Sequence) {
        print('Private key top level is not an ASN1Sequence');
        return null;
      }

      // Check if this is PKCS#8 or PKCS#1 format
      if (pkSeq.elements.length >= 9 &&
          pkSeq.elements[0] is asn1lib.ASN1Integer) {
        // Check first element - if it's 0, this might be PKCS#1
        var firstElement = pkSeq.elements[0] as asn1lib.ASN1Integer;
        if (firstElement.valueAsBigInteger == BigInt.zero &&
            pkSeq.elements.length == 9) {
          // PKCS#1 format
          var modulus =
              (pkSeq.elements[1] as asn1lib.ASN1Integer).valueAsBigInteger;
          var publicExponent =
              (pkSeq.elements[2] as asn1lib.ASN1Integer).valueAsBigInteger;
          var privateExponent =
              (pkSeq.elements[3] as asn1lib.ASN1Integer).valueAsBigInteger;
          var p = (pkSeq.elements[4] as asn1lib.ASN1Integer).valueAsBigInteger;
          var q = (pkSeq.elements[5] as asn1lib.ASN1Integer).valueAsBigInteger;

          if (modulus == null ||
              privateExponent == null ||
              p == null ||
              q == null) {
            print('PKCS#1: Null key component');
            return null;
          }

          return RSAPrivateKey(modulus, privateExponent, p, q);
        }
      }

      // PKCS#8 format
      if (pkSeq.elements.length >= 3) {
        var privateKeyOctetString = pkSeq.elements[2];

        if (privateKeyOctetString is! asn1lib.ASN1OctetString) {
          print('PKCS#8: Third element is not an ASN1OctetString');
          return null;
        }

        var privateKeyBytes = privateKeyOctetString.valueBytes();
        if (privateKeyBytes == null || privateKeyBytes.isEmpty) {
          print('PKCS#8: Empty private key bytes');
          return null;
        }

        var privateKeyParser = asn1lib.ASN1Parser(privateKeyBytes);
        var rsaPrivateKeySeq = privateKeyParser.nextObject();

        if (rsaPrivateKeySeq is! asn1lib.ASN1Sequence) {
          print('PKCS#8: RSA private key is not an ASN1Sequence');
          return null;
        }

        if (rsaPrivateKeySeq.elements.length < 6) {
          print('PKCS#8: Insufficient elements in RSA private key sequence');
          return null;
        }

        var modulus = (rsaPrivateKeySeq.elements[1] as asn1lib.ASN1Integer)
            .valueAsBigInteger;
        var publicExponent =
            (rsaPrivateKeySeq.elements[2] as asn1lib.ASN1Integer)
                .valueAsBigInteger;
        var privateExponent =
            (rsaPrivateKeySeq.elements[3] as asn1lib.ASN1Integer)
                .valueAsBigInteger;
        var p = (rsaPrivateKeySeq.elements[4] as asn1lib.ASN1Integer)
            .valueAsBigInteger;
        var q = (rsaPrivateKeySeq.elements[5] as asn1lib.ASN1Integer)
            .valueAsBigInteger;

        if (modulus == null ||
            privateExponent == null ||
            p == null ||
            q == null) {
          print('PKCS#8: Null key component');
          return null;
        }

        return RSAPrivateKey(modulus, privateExponent, p, q);
      }

      print('Unsupported private key format');
      return null;
    } catch (e, stackTrace) {
      print('Error parsing private key: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Uint8List _decodePEM(String pem) {
  //   try {
  //     if (pem.trim().isEmpty) {
  //       throw FormatException('Empty PEM string');
  //     }
  //
  //     // Normalize line endings and remove any extra whitespace
  //     String normalizedPem = pem
  //         .replaceAll('\r\n', '\n')
  //         .replaceAll('\r', '\n')
  //         .trim();
  //
  //     // Find the start and end markers
  //     int startMarkerStart = normalizedPem.indexOf('-----BEGIN');
  //     if (startMarkerStart == -1) {
  //       throw FormatException('Invalid PEM format: missing BEGIN marker');
  //     }
  //
  //     int startMarkerEnd = normalizedPem.indexOf('-----', startMarkerStart + 5);
  //     if (startMarkerEnd == -1) {
  //       throw FormatException('Invalid PEM format: malformed BEGIN marker');
  //     }
  //
  //     int endMarkerStart = normalizedPem.indexOf('-----END');
  //     if (endMarkerStart == -1) {
  //       throw FormatException('Invalid PEM format: missing END marker');
  //     }
  //
  //     // Extract the base64 content between the markers
  //     String base64Content = normalizedPem
  //         .substring(startMarkerEnd + 5, endMarkerStart)
  //         .trim();
  //
  //     // Remove any whitespace and newlines from the base64 content
  //     base64Content = base64Content.replaceAll(RegExp(r'\s+'), '');
  //
  //     if (base64Content.isEmpty) {
  //       throw FormatException('Invalid PEM format: empty content');
  //     }
  //
  //     // Validate base64 format
  //     if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(base64Content)) {
  //       throw FormatException('Invalid PEM format: invalid base64 characters');
  //     }
  //
  //     return base64.decode(base64Content);
  //   } catch (e) {
  //     print('PEM decode error: $e');
  //     print('PEM content length: ${pem.length}');
  //     print(
  //       'PEM content preview: ${pem.length > 100 ? pem.substring(0, 100) + '...' : pem}',
  //     );
  //     rethrow;
  //   }
  // }
}
