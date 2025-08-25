import 'package:flutter/foundation.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import 'dart:convert';
import 'package:oqs/src/signature.dart';
import 'ml_dsa_key_storage_service.dart';

class MlDsaKeyService {
  final MlDsaKeyStorageService _storageService;
  final String _algorithm;
  Signature? _signature;

  // Constructor with dependency injection for storage service
  MlDsaKeyService({
    MlDsaKeyStorageService? storageService,
    String algorithm = 'ML-DSA-65', // Default to ML-DSA-65
  }) : _storageService = storageService ?? MlDsaKeyStorageService(),
       _algorithm = algorithm {
    _initializeSignature();
  }

  /// Initialize the Signature instance
  void _initializeSignature() {
    _signature = Signature.create(_algorithm);
    if (_signature == null) {
      throw Exception('ML-DSA algorithm $_algorithm not supported');
    }
  }

  /// Dispose of the Signature instance when done
  void dispose() {
    _signature?.dispose();
    _signature = null;
  }

  // Delegate storage operations to the storage service
  Future<List<QryptMLDSAKeyPair>> getKeyPairs() =>
      _storageService.getKeyPairs();

  Future<void> saveKeyPair(QryptMLDSAKeyPair keyPair) =>
      _storageService.saveKeyPair(keyPair);

  Future<void> deleteKeyPair(String id) => _storageService.deleteKeyPair(id);

  Future<void> updateKeyPair(QryptMLDSAKeyPair updatedKeyPair) =>
      _storageService.updateKeyPair(updatedKeyPair);

  Future<QryptMLDSAKeyPair?> getKeyPairById(String id) =>
      _storageService.getKeyPairById(id);

  Future<List<QryptMLDSAKeyPair>> searchKeyPairsByName(String searchTerm) =>
      _storageService.searchKeyPairsByName(searchTerm);

  Future<List<QryptMLDSAKeyPair>> getKeyPairsByAlgorithm(String algorithm) =>
      _storageService.getKeyPairsByAlgorithm(algorithm);

  // Clear all key pairs
  Future<void> clearAllKeyPairs() async {
    await _storageService.clearAllKeyPairs();
  }

  // Additional storage convenience methods
  Future<bool> keyPairExists(String id) async {
    final keyPair = await _storageService.getKeyPairById(id);
    return keyPair != null;
  }

  Future<bool> keyPairNameExists(String name) async {
    return await _storageService.keyPairNameExists(name);
  }

  Future<int> getKeyPairsCount() async {
    final keyPairs = await _storageService.getKeyPairs();
    return keyPairs.length;
  }

  bool _isGenerating = false;

  /// Generates a new ML-DSA key pair with the specified name
  Future<QryptMLDSAKeyPair> generateKeyPair(
    String name, {
    String? description,
  }) async {
    if (_isGenerating) {
      throw Exception('Key generation already in progress');
    }

    if (_signature == null) {
      throw Exception('ML-DSA Signature not initialized');
    }

    try {
      _isGenerating = true;

      // Check if name already exists
      if (await keyPairNameExists(name)) {
        throw Exception('A key pair with the name "$name" already exists');
      }

      // Generate the ML-DSA key pair using OQS
      final signatureKeyPair = _signature!.generateKeyPair();

      // Create QryptMLDSAKeyPair with metadata
      final qryptKeyPair = QryptMLDSAKeyPair.create(
        name: name,
        signatureKeyPair: signatureKeyPair,
        description: description,
        algorithm: _algorithm,
      );

      await saveKeyPair(qryptKeyPair);
      return qryptKeyPair;
    } catch (e) {
      debugPrint('Error generating ML-DSA key pair: $e');
      rethrow;
    } finally {
      _isGenerating = false;
    }
  }

  /// Imports an existing ML-DSA key pair from raw bytes
  Future<QryptMLDSAKeyPair> importKeyPair({
    required String name,
    required Uint8List publicKeyBytes,
    required Uint8List secretKeyBytes,
    String? description,
  }) async {
    try {
      // Check if name already exists
      if (await keyPairNameExists(name)) {
        throw Exception('A key pair with the name "$name" already exists');
      }

      // Create SignatureKeyPair from the raw bytes
      final signatureKeyPair = SignatureKeyPair(
        publicKey: publicKeyBytes,
        secretKey: secretKeyBytes,
      );

      // Validate the key pair by testing sign/verify
      if (!await validateKeyPair(signatureKeyPair)) {
        throw Exception('Invalid key pair - keys do not work together');
      }

      final qryptKeyPair = QryptMLDSAKeyPair.create(
        name: name,
        signatureKeyPair: signatureKeyPair,
        description: description,
        algorithm: _algorithm,
      );

      await saveKeyPair(qryptKeyPair);
      return qryptKeyPair;
    } catch (e) {
      debugPrint('Error importing ML-DSA key pair: $e');
      rethrow;
    }
  }

  /// Validates that a ML-DSA key pair works by testing sign/verify
  Future<bool> validateKeyPair(SignatureKeyPair keyPair) async {
    if (_signature == null) return false;

    try {
      // Test message
      final testMessage = Uint8List.fromList('test message'.codeUnits);

      // Test signing with the secret key
      final signature = _signature!.sign(testMessage, keyPair.secretKey);

      // Test verification with the public key
      final isValid = _signature!.verify(
        testMessage,
        signature,
        keyPair.publicKey,
      );

      return isValid;
    } catch (e) {
      debugPrint('Key validation error: $e');
      return false;
    }
  }

  /// Signs a message using a secret key
  Uint8List signMessage(Uint8List message, Uint8List secretKey) {
    if (_signature == null) {
      throw Exception('ML-DSA Signature not initialized');
    }

    try {
      return _signature!.sign(message, secretKey);
    } catch (e) {
      debugPrint('Signing error: $e');
      rethrow;
    }
  }

  /// Signs a message using a stored key pair's secret key
  Future<Uint8List> signMessageWithStoredKey(
    Uint8List message,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return signMessage(message, keyPair.secretKey);
    } catch (e) {
      debugPrint('Signing with stored key error: $e');
      rethrow;
    }
  }

  /// Verifies a signature using a public key
  bool verifySignature(
    Uint8List message,
    Uint8List signature,
    Uint8List publicKey,
  ) {
    if (_signature == null) {
      throw Exception('ML-DSA Signature not initialized');
    }

    try {
      return _signature!.verify(message, signature, publicKey);
    } catch (e) {
      debugPrint('Verification error: $e');
      rethrow;
    }
  }

  /// Verifies a signature using a stored key pair's public key
  Future<bool> verifySignatureWithStoredKey(
    Uint8List message,
    Uint8List signature,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return verifySignature(message, signature, keyPair.publicKey);
    } catch (e) {
      debugPrint('Verification with stored key error: $e');
      rethrow;
    }
  }

  /// Gets the current algorithm name
  String get algorithm => _algorithm;

  /// Gets algorithm information with key sizes
  Map<String, dynamic> getAlgorithmInfo() {
    if (_signature == null) {
      return {
        'algorithm': _algorithm,
        'isInitialized': false,
        'publicKeySize': 0,
        'secretKeySize': 0,
        'maxSignatureSize': 0,
      };
    }

    return {
      'algorithm': _algorithm,
      'isInitialized': true,
      'publicKeySize': _signature!.publicKeyLength,
      'secretKeySize': _signature!.secretKeyLength,
      'maxSignatureSize': _signature!.maxSignatureLength,
    };
  }

  /// Gets the expected sizes for ML-DSA algorithms
  Map<String, int> _getAlgorithmSizes(String algorithm) {
    switch (algorithm) {
      case 'ML-DSA-44':
        return {
          'publicKeySize': 1312,
          'secretKeySize': 2560,
          'maxSignatureSize': 2420,
        };
      case 'ML-DSA-65':
        return {
          'publicKeySize': 1952,
          'secretKeySize': 4032,
          'maxSignatureSize': 3309,
        };
      case 'ML-DSA-87':
        return {
          'publicKeySize': 2592,
          'secretKeySize': 4896,
          'maxSignatureSize': 4627,
        };
      default:
        return {'publicKeySize': 0, 'secretKeySize': 0, 'maxSignatureSize': 0};
    }
  }

  /// Exports a key pair to a portable format (JSON with base64 encoded keys)
  Future<Map<String, dynamic>> exportKeyPair(String keyPairId) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }

      return {
        'id': keyPair.id,
        'name': keyPair.name,
        'algorithm': keyPair.algorithm,
        'publicKey': base64Encode(keyPair.publicKey),
        'secretKey': base64Encode(keyPair.secretKey),
        'description': keyPair.description,
        'createdAt': keyPair.createdAt.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error exporting ML-DSA key pair: $e');
      rethrow;
    }
  }

  /// Gets storage information and statistics
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      return await _storageService.getStorageStats();
    } catch (e) {
      debugPrint('Error getting ML-DSA storage info: $e');
      return {
        'keyPairsCount': 0,
        'totalPublicKeySize': 0,
        'totalSecretKeySize': 0,
        'totalSize': 0,
        'algorithms': <String>[],
        'averageKeyPairSize': 0,
      };
    }
  }

  /// Gets key pairs sorted by creation date
  Future<List<QryptMLDSAKeyPair>> getKeyPairsSortedByDate({
    bool ascending = false,
  }) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.sort(
        (a, b) => ascending
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt),
      );
      return keyPairs;
    } catch (e) {
      debugPrint('Error sorting ML-DSA key pairs: $e');
      return [];
    }
  }

  /// Validates key pair names (no special characters, reasonable length)
  bool _isValidKeyPairName(String name) {
    if (name.isEmpty || name.length > 100) return false;
    // Allow alphanumeric, spaces, hyphens, underscores
    final validNameRegex = RegExp(r'^[a-zA-Z0-9\s\-_]+$');
    return validNameRegex.hasMatch(name);
  }

  /// Creates a key pair with validation
  Future<QryptMLDSAKeyPair> generateValidatedKeyPair(
    String name, {
    String? description,
  }) async {
    // Validate name
    if (!_isValidKeyPairName(name)) {
      throw Exception(
        'Invalid key pair name. Use only alphanumeric characters, spaces, hyphens, and underscores. Max length: 100 characters.',
      );
    }

    return generateKeyPair(name, description: description);
  }

  /// Gets a summary of all algorithms used in stored key pairs
  Future<Map<String, int>> getAlgorithmSummary() async {
    try {
      final keyPairs = await getKeyPairs();
      final Map<String, int> summary = {};

      for (final keyPair in keyPairs) {
        final algorithm = keyPair.algorithm;
        summary[algorithm] = (summary[algorithm] ?? 0) + 1;
      }

      return summary;
    } catch (e) {
      debugPrint('Error getting ML-DSA algorithm summary: $e');
      return {};
    }
  }

  /// Gets all supported ML-DSA algorithms
  static List<String> getSupportedAlgorithms() {
    return Signature.getSupportedSignatureAlgorithms()
        .where((alg) => alg.startsWith('ML-DSA'))
        .toList();
  }

  /// Checks if the current Signature instance is healthy
  bool get isHealthy {
    if (_signature == null) return false;

    try {
      // Test basic functionality
      final testKeyPair = _signature!.generateKeyPair();
      final testMessage = Uint8List.fromList('health check'.codeUnits);
      final signature = _signature!.sign(testMessage, testKeyPair.secretKey);
      return _signature!.verify(testMessage, signature, testKeyPair.publicKey);
    } catch (e) {
      return false;
    }
  }

  /// Reinitializes the Signature instance if needed
  Future<void> ensureHealthy() async {
    if (!isHealthy) {
      dispose();
      _initializeSignature();
    }
  }

  /// Signs a string message (convenience method)
  Future<Uint8List> signStringMessage(String message, String keyPairId) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    return signMessageWithStoredKey(messageBytes, keyPairId);
  }

  /// Verifies a string message signature (convenience method)
  Future<bool> verifyStringMessage(
    String message,
    Uint8List signature,
    String keyPairId,
  ) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    return verifySignatureWithStoredKey(messageBytes, signature, keyPairId);
  }

  /// Batch sign multiple messages with the same key
  Future<List<Uint8List>> batchSignMessages(
    List<Uint8List> messages,
    String keyPairId,
  ) async {
    final List<Uint8List> signatures = [];

    for (final message in messages) {
      final signature = await signMessageWithStoredKey(message, keyPairId);
      signatures.add(signature);
    }

    return signatures;
  }

  /// Batch verify multiple message-signature pairs with the same key
  Future<List<bool>> batchVerifySignatures(
    List<Uint8List> messages,
    List<Uint8List> signatures,
    String keyPairId,
  ) async {
    if (messages.length != signatures.length) {
      throw Exception(
        'Messages and signatures lists must have the same length',
      );
    }

    final List<bool> results = [];

    for (int i = 0; i < messages.length; i++) {
      final isValid = await verifySignatureWithStoredKey(
        messages[i],
        signatures[i],
        keyPairId,
      );
      results.add(isValid);
    }

    return results;
  }
}
