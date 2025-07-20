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
    var version = asn1lib.ASN1Integer(BigInt.from(0));
    var modulus = asn1lib.ASN1Integer(privateKey.n!);
    var publicExponent = asn1lib.ASN1Integer(privateKey.exponent!);
    var privateExponent = asn1lib.ASN1Integer(privateKey.d!);
    var p = asn1lib.ASN1Integer(privateKey.p!);
    var q = asn1lib.ASN1Integer(privateKey.q!);
    var dP = privateKey.d! % (privateKey.p! - BigInt.one);
    var dQ = privateKey.d! % (privateKey.q! - BigInt.one);
    var qInv = privateKey.q!.modInverse(privateKey.p!);

    var seq = asn1lib.ASN1Sequence();
    seq.add(version);
    seq.add(modulus);
    seq.add(publicExponent);
    seq.add(privateExponent);
    seq.add(p);
    seq.add(q);
    seq.add(asn1lib.ASN1Integer(dP));
    seq.add(asn1lib.ASN1Integer(dQ));
    seq.add(asn1lib.ASN1Integer(qInv));

    var dataBase64 = base64.encode(seq.encodedBytes);
    var chunks = <String>[];
    for (var i = 0; i < dataBase64.length; i += 64) {
      var end = (i + 64 < dataBase64.length) ? i + 64 : dataBase64.length;
      chunks.add(dataBase64.substring(i, end));
    }

    return "-----BEGIN PRIVATE KEY-----\n${chunks.join('\n')}\n-----END PRIVATE KEY-----";
  }

  RSAPublicKey? _parsePublicKey(String pemString) {
    try {
      final publicKeyDER = _decodePEM(pemString);
      var asn1Parser = asn1lib.ASN1Parser(publicKeyDER);
      var topLevelSeq = asn1Parser.nextObject() as asn1lib.ASN1Sequence;

      var publicKeyBitString = topLevelSeq.elements[1] as asn1lib.ASN1BitString;
      var publicKeyAsn = asn1lib.ASN1Parser(publicKeyBitString.valueBytes());
      var publicKeySeq = publicKeyAsn.nextObject() as asn1lib.ASN1Sequence;

      var modulus = publicKeySeq.elements[0] as asn1lib.ASN1Integer;
      var exponent = publicKeySeq.elements[1] as asn1lib.ASN1Integer;

      return RSAPublicKey(
        modulus.valueAsBigInteger,
        exponent.valueAsBigInteger,
      );
    } catch (e) {
      print('Error parsing public key: $e');
      return null;
    }
  }

  RSAPrivateKey? _parsePrivateKey(String pemString) {
    try {
      final privateKeyDER = _decodePEM(pemString);
      var asn1Parser = asn1lib.ASN1Parser(privateKeyDER);
      var pkSeq = asn1Parser.nextObject() as asn1lib.ASN1Sequence;

      var modulus =
          (pkSeq.elements[1] as asn1lib.ASN1Integer).valueAsBigInteger;
      var publicExponent =
          (pkSeq.elements[2] as asn1lib.ASN1Integer).valueAsBigInteger;
      var privateExponent =
          (pkSeq.elements[3] as asn1lib.ASN1Integer).valueAsBigInteger;
      var p = (pkSeq.elements[4] as asn1lib.ASN1Integer).valueAsBigInteger;
      var q = (pkSeq.elements[5] as asn1lib.ASN1Integer).valueAsBigInteger;

      return RSAPrivateKey(modulus, privateExponent, p, q);
    } catch (e) {
      print('Error parsing private key: $e');
      return null;
    }
  }

  Uint8List _decodePEM(String pem) {
    final startTag = pem.indexOf('-----BEGIN');
    final endTag = pem.indexOf('-----END');
    final base64String = pem
        .substring(startTag, endTag)
        .replaceAll(RegExp(r'-----[^-]*-----'), '')
        .replaceAll(RegExp(r'\s+'), '');
    return base64.decode(base64String);
  }
}
