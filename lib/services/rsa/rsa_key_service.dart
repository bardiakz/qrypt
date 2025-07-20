import 'package:asn1lib/asn1lib.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/api.dart' hide Signer;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart'
    hide ASN1Integer;
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart'
    hide ASN1Sequence;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

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

  /// Helper method to create a secure random number generator
  FortunaRandom _createSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(random.nextInt(256));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Converts an RSA public key to PEM format
  String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final algorithmSeq = ASN1Sequence();
    final algorithmAsn1Obj = ASN1Object.fromBytes(
      Uint8List.fromList([
        0x06,
        0x09,
        0x2a,
        0x86,
        0x48,
        0x86,
        0xf7,
        0x0d,
        0x01,
        0x01,
        0x01,
      ]),
    );
    final paramsAsn1Obj = ASN1Object.fromBytes(
      Uint8List.fromList([0x05, 0x00]),
    );
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    final publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(publicKey.modulus!));
    publicKeySeq.add(ASN1Integer(publicKey.exponent!));
    final publicKeySeqBitString = ASN1BitString(publicKeySeq.encodedBytes);

    final topLevelSeq = ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeySeqBitString);

    final dataBase64 = base64.encode(topLevelSeq.encodedBytes);
    return '-----BEGIN PUBLIC KEY-----\n${_formatBase64(dataBase64)}\n-----END PUBLIC KEY-----';
  }

  /// Converts an RSA private key to PEM format
  String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final version = ASN1Integer(BigInt.from(0));
    final modulus = ASN1Integer(privateKey.modulus!);
    final publicExponent = ASN1Integer(privateKey.exponent!);
    final privateExponent = ASN1Integer(privateKey.privateExponent!);
    final p = ASN1Integer(privateKey.p!);
    final q = ASN1Integer(privateKey.q!);
    final dP = ASN1Integer(
      privateKey.privateExponent! % (privateKey.p! - BigInt.one),
    );
    final dQ = ASN1Integer(
      privateKey.privateExponent! % (privateKey.q! - BigInt.one),
    );
    final qInv = ASN1Integer(privateKey.q!.modInverse(privateKey.p!));

    final seq = ASN1Sequence();
    seq.add(version);
    seq.add(modulus);
    seq.add(publicExponent);
    seq.add(privateExponent);
    seq.add(p);
    seq.add(q);
    seq.add(dP);
    seq.add(dQ);
    seq.add(qInv);

    final dataBase64 = base64.encode(seq.encodedBytes);
    return '-----BEGIN RSA PRIVATE KEY-----\n${_formatBase64(dataBase64)}\n-----END RSA PRIVATE KEY-----';
  }

  /// Formats base64 string into 64-character lines
  String _formatBase64(String base64String) {
    final regex = RegExp('.{1,64}');
    return regex
        .allMatches(base64String)
        .map((match) => match.group(0))
        .join('\n');
  }

  /// Generates a new RSA key pair with the specified name and key size
  Future<RSAKeyPair> generateKeyPair(String name, {int keySize = 2048}) async {
    try {
      // Check if name already exists
      if (await keyPairNameExists(name)) {
        throw Exception('A key pair with the name "$name" already exists');
      }

      // Create RSA key generator
      final keyGen = RSAKeyGenerator();
      final secureRandom = _createSecureRandom();

      // Initialize key generator with parameters
      keyGen.init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), keySize, 64),
          secureRandom,
        ),
      );

      // Generate the key pair
      final keyPair = keyGen.generateKeyPair();
      final publicKey = keyPair.publicKey as RSAPublicKey;
      final privateKey = keyPair.privateKey as RSAPrivateKey;

      // Convert keys to PEM format
      final publicKeyPem = _encodePublicKeyToPem(publicKey);
      final privateKeyPem = _encodePrivateKeyToPem(privateKey);

      final rsaKeyPair = RSAKeyPair(
        id: const Uuid().v4(),
        name: name,
        publicKey: publicKeyPem,
        privateKey: privateKeyPem,
        createdAt: DateTime.now(),
      );

      await saveKeyPair(rsaKeyPair);
      return rsaKeyPair;
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
      final parser = RSAKeyParser();
      final publicKey = parser.parse(publicKeyPem) as RSAPublicKey;
      final privateKey = parser.parse(privateKeyPem) as RSAPrivateKey;

      // Test encryption/decryption to validate the key pair
      final plaintext = 'test message for validation';

      // Create encrypter with public key
      final encrypter = Encrypter(
        RSA(publicKey: publicKey, privateKey: privateKey),
      );

      // Encrypt with public key and decrypt with private key
      final encrypted = encrypter.encrypt(plaintext);
      final decrypted = encrypter.decrypt(encrypted);

      return decrypted == plaintext;
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
      final parser = RSAKeyParser();
      final publicKey = parser.parse(publicKeyPem) as RSAPublicKey;

      final encrypter = Encrypter(RSA(publicKey: publicKey));
      final encrypted = encrypter.encrypt(plaintext);

      return encrypted.base64;
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
      final parser = RSAKeyParser();
      final privateKey = parser.parse(privateKeyPem) as RSAPrivateKey;

      final encrypter = Encrypter(RSA(privateKey: privateKey));
      final encrypted = Encrypted.fromBase64(ciphertext);

      return encrypter.decrypt(encrypted);
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
      final parser = RSAKeyParser();
      final privateKey = parser.parse(privateKeyPem) as RSAPrivateKey;

      final signer = Signer(
        RSASigner(RSASignDigest.SHA256, privateKey: privateKey),
      );
      final signature = signer.sign(message);

      return signature.base64;
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
      final parser = RSAKeyParser();
      final publicKey = parser.parse(publicKeyPem) as RSAPublicKey;

      final signer = Signer(
        RSASigner(RSASignDigest.SHA256, publicKey: publicKey),
      );
      final signatureEncrypted = Encrypted.fromBase64(signature);

      return signer.verify(message, signatureEncrypted);
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
      final parser = RSAKeyParser();
      final publicKey = parser.parse(publicKeyPem) as RSAPublicKey;

      // Get the modulus from the key and calculate bit length
      final modulus = publicKey.n;
      return modulus?.bitLength ?? 0;
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

  /// Encrypts data using hybrid encryption (RSA + AES)
  /// This is useful for encrypting larger amounts of data
  Future<Map<String, String>> encryptLargeData(
    String plaintext,
    String publicKeyPem,
  ) async {
    try {
      // Generate a random AES key
      final aesKey = Key.fromSecureRandom(32);
      final iv = IV.fromSecureRandom(16);

      // Encrypt data with AES
      final aesEncrypter = Encrypter(AES(aesKey));
      final encryptedData = aesEncrypter.encrypt(plaintext, iv: iv);

      // Encrypt AES key with RSA
      final encryptedAESKey = await encryptWithPublicKey(
        aesKey.base64,
        publicKeyPem,
      );

      return {
        'encryptedData': encryptedData.base64,
        'encryptedKey': encryptedAESKey,
        'iv': iv.base64,
      };
    } catch (e) {
      print('Large data encryption error: $e');
      rethrow;
    }
  }

  /// Decrypts data encrypted with hybrid encryption (RSA + AES)
  Future<String> decryptLargeData(
    Map<String, String> encryptedPackage,
    String privateKeyPem,
  ) async {
    try {
      // Decrypt AES key with RSA
      final aesKeyBase64 = await decryptWithPrivateKey(
        encryptedPackage['encryptedKey']!,
        privateKeyPem,
      );

      // Reconstruct AES components
      final aesKey = Key.fromBase64(aesKeyBase64);
      final iv = IV.fromBase64(encryptedPackage['iv']!);
      final encryptedData = Encrypted.fromBase64(
        encryptedPackage['encryptedData']!,
      );

      // Decrypt data with AES
      final aesEncrypter = Encrypter(AES(aesKey));
      return aesEncrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      print('Large data decryption error: $e');
      rethrow;
    }
  }

  /// Encrypts large data using a stored public key
  Future<Map<String, String>> encryptLargeDataWithStoredKey(
    String plaintext,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return await encryptLargeData(plaintext, keyPair.publicKey);
    } catch (e) {
      print('Large data encryption with stored key error: $e');
      rethrow;
    }
  }

  /// Decrypts large data using a stored private key
  Future<String> decryptLargeDataWithStoredKey(
    Map<String, String> encryptedPackage,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return await decryptLargeData(encryptedPackage, keyPair.privateKey);
    } catch (e) {
      print('Large data decryption with stored key error: $e');
      rethrow;
    }
  }
}
