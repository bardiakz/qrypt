import 'package:flutter/foundation.dart';
import 'package:oqs/oqs.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'dart:convert';

import 'kem_key_storage_service.dart';

class KemKeyService {
  final KemKeyStorageService _storageService;
  final String _algorithm;
  KEM? _kem;

  // Constructor with dependency injection for storage service
  KemKeyService({
    KemKeyStorageService? storageService,
    String algorithm = 'ML-KEM-768', // Default to ML-KEM-768
  }) : _storageService = storageService ?? KemKeyStorageService(),
       _algorithm = algorithm {
    _initializeKEM();
  }

  /// Initialize the KEM instance
  void _initializeKEM() {
    _kem = KEM.create(_algorithm);
    if (_kem == null) {
      throw Exception('Algorithm $_algorithm not supported');
    }
  }

  /// Dispose of the KEM instance when done
  void dispose() {
    _kem?.dispose();
    _kem = null;
  }

  // Delegate storage operations to the storage service
  Future<List<QryptKEMKeyPair>> getKeyPairs() => _storageService.getKeyPairs();

  Future<void> saveKeyPair(QryptKEMKeyPair keyPair) =>
      _storageService.saveKeyPair(keyPair);

  Future<void> deleteKeyPair(String id) => _storageService.deleteKeyPair(id);

  Future<void> updateKeyPair(QryptKEMKeyPair updatedKeyPair) =>
      _storageService.updateKeyPair(updatedKeyPair);

  Future<QryptKEMKeyPair?> getKeyPairById(String id) =>
      _storageService.getKeyPairById(id);

  Future<List<QryptKEMKeyPair>> searchKeyPairsByName(String searchTerm) =>
      _storageService.searchKeyPairsByName(searchTerm);

  // Clear all key pairs - handle if method doesn't exist
  Future<void> clearAllKeyPairs() async {
    final keyPairs = await _storageService.getKeyPairs();
    for (final keyPair in keyPairs) {
      await _storageService.deleteKeyPair(keyPair.id);
    }
  }

  // Additional storage convenience methods - implement locally
  Future<bool> keyPairExists(String id) async {
    final keyPair = await _storageService.getKeyPairById(id);
    return keyPair != null;
  }

  Future<bool> keyPairNameExists(String name) async {
    final keyPairs = await _storageService.getKeyPairs();
    return keyPairs.any((kp) => kp.name.toLowerCase() == name.toLowerCase());
  }

  Future<int> getKeyPairsCount() async {
    final keyPairs = await _storageService.getKeyPairs();
    return keyPairs.length;
  }

  bool _isGenerating = false;

  /// Generates a new ML-KEM key pair with the specified name
  Future<QryptKEMKeyPair> generateKeyPair(
    String name, {
    String? description,
  }) async {
    if (_isGenerating) {
      throw Exception('Key generation already in progress');
    }

    if (_kem == null) {
      throw Exception('KEM not initialized');
    }

    try {
      _isGenerating = true;

      // Check if name already exists
      if (await keyPairNameExists(name)) {
        throw Exception('A key pair with the name "$name" already exists');
      }

      // Generate the KEM key pair using OQS
      final kemKeyPair = _kem!.generateKeyPair();

      // Create QryptKEMKeyPair with metadata
      final qryptKeyPair = QryptKEMKeyPair.create(
        name: name,
        kemKeyPair: kemKeyPair,
        description: description,
        algorithm: _algorithm,
      );

      await saveKeyPair(qryptKeyPair);
      return qryptKeyPair;
    } catch (e) {
      debugPrint('Error generating key pair: $e');
      rethrow;
    } finally {
      _isGenerating = false;
    }
  }

  /// Imports an existing KEM key pair from raw bytes
  Future<QryptKEMKeyPair> importKeyPair({
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

      // Create KEMKeyPair from the raw bytes
      final kemKeyPair = KEMKeyPair(
        publicKey: publicKeyBytes,
        secretKey: secretKeyBytes,
      );

      // Validate the key pair by testing encapsulation/decapsulation
      if (!await _validateKeyPair(kemKeyPair)) {
        throw Exception('Invalid key pair - keys do not work together');
      }

      final qryptKeyPair = QryptKEMKeyPair.create(
        name: name,
        kemKeyPair: kemKeyPair,
        description: description,
        algorithm: _algorithm,
      );

      await saveKeyPair(qryptKeyPair);
      return qryptKeyPair;
    } catch (e) {
      debugPrint('Error importing key pair: $e');
      rethrow;
    }
  }

  /// Validates that a KEM key pair works by testing encapsulation/decapsulation
  Future<bool> _validateKeyPair(KEMKeyPair keyPair) async {
    if (_kem == null) return false;

    try {
      // Test encapsulation with the public key
      // Based on your main() example, encapsulate returns an object with .ciphertext and .sharedSecret
      final encapsulationResult = _kem!.encapsulate(keyPair.publicKey);

      // Test decapsulation with the secret key
      final decapsulatedSecret = _kem!.decapsulate(
        encapsulationResult.ciphertext,
        keyPair.secretKey,
      );

      // Verify the shared secrets match (using your _listsEqual function)
      return _listsEqual(encapsulationResult.sharedSecret, decapsulatedSecret);
    } catch (e) {
      debugPrint('Key validation error: $e');
      return false;
    }
  }

  /// Encapsulates a shared secret using a public key
  /// Returns the result from the OQS encapsulate method directly
  dynamic encapsulateWithPublicKey(Uint8List publicKey) {
    if (_kem == null) {
      throw Exception('KEM not initialized');
    }

    try {
      return _kem!.encapsulate(publicKey);
    } catch (e) {
      debugPrint('Encapsulation error: $e');
      rethrow;
    }
  }

  /// Encapsulates a shared secret using a stored key pair's public key
  Future<dynamic> encapsulateWithStoredPublicKey(String keyPairId) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return encapsulateWithPublicKey(keyPair.publicKey);
    } catch (e) {
      debugPrint('Encapsulation with stored key error: $e');
      rethrow;
    }
  }

  /// Decapsulates a shared secret using a secret key
  Uint8List decapsulateWithSecretKey(
    Uint8List ciphertext,
    Uint8List secretKey,
  ) {
    if (_kem == null) {
      throw Exception('KEM not initialized');
    }

    try {
      return _kem!.decapsulate(ciphertext, secretKey);
    } catch (e) {
      debugPrint('Decapsulation error: $e');
      rethrow;
    }
  }

  /// Decapsulates a shared secret using a stored key pair's secret key
  Future<Uint8List> decapsulateWithStoredSecretKey(
    Uint8List ciphertext,
    String keyPairId,
  ) async {
    try {
      final keyPair = await getKeyPairById(keyPairId);
      if (keyPair == null) {
        throw Exception('Key pair not found');
      }
      return decapsulateWithSecretKey(ciphertext, keyPair.secretKey);
    } catch (e) {
      debugPrint('Decapsulation with stored key error: $e');
      rethrow;
    }
  }

  /// Gets the current algorithm name
  String get algorithm => _algorithm;

  /// Gets algorithm information with key sizes
  Map<String, dynamic> getAlgorithmInfo() {
    Map<String, int> sizes = _getAlgorithmSizes(_algorithm);

    return {
      'algorithm': _algorithm,
      'isInitialized': _kem != null,
      'publicKeySize': sizes['publicKeySize'],
      'secretKeySize': sizes['secretKeySize'],
      'ciphertextSize': sizes['ciphertextSize'],
      'sharedSecretSize': sizes['sharedSecretSize'],
    };
  }

  /// Gets the expected sizes for ML-KEM algorithms
  Map<String, int> _getAlgorithmSizes(String algorithm) {
    switch (algorithm) {
      case 'ML-KEM-512':
        return {
          'publicKeySize': 800,
          'secretKeySize': 1632,
          'ciphertextSize': 768,
          'sharedSecretSize': 32,
        };
      case 'ML-KEM-768':
        return {
          'publicKeySize': 1184,
          'secretKeySize': 2400,
          'ciphertextSize': 1088,
          'sharedSecretSize': 32,
        };
      case 'ML-KEM-1024':
        return {
          'publicKeySize': 1568,
          'secretKeySize': 3168,
          'ciphertextSize': 1568,
          'sharedSecretSize': 32,
        };
      default:
        return {
          'publicKeySize': 0,
          'secretKeySize': 0,
          'ciphertextSize': 0,
          'sharedSecretSize': 32,
        };
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
      debugPrint('Error exporting key pair: $e');
      rethrow;
    }
  }

  /// Gets storage information and statistics
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final keyPairs = await getKeyPairs();
      final totalPublicKeySize = keyPairs.fold<int>(
        0,
        (sum, kp) => sum + kp.publicKeySize,
      );
      final totalSecretKeySize = keyPairs.fold<int>(
        0,
        (sum, kp) => sum + kp.secretKeySize,
      );

      return {
        'keyPairsCount': keyPairs.length,
        'totalPublicKeySize': totalPublicKeySize,
        'totalSecretKeySize': totalSecretKeySize,
        'totalSize': totalPublicKeySize + totalSecretKeySize,
        'algorithms': keyPairs.map((kp) => kp.algorithm).toSet().toList(),
        'averageKeyPairSize': keyPairs.isEmpty
            ? 0
            : (totalPublicKeySize + totalSecretKeySize) ~/ keyPairs.length,
      };
    } catch (e) {
      debugPrint('Error getting storage info: $e');
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
  Future<List<QryptKEMKeyPair>> getKeyPairsSortedByDate({
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
      debugPrint('Error sorting key pairs: $e');
      return [];
    }
  }

  /// Helper method to compare two lists (from your main() example)
  bool _listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Validates key pair names (no special characters, reasonable length)
  bool _isValidKeyPairName(String name) {
    if (name.isEmpty || name.length > 100) return false;
    // Allow alphanumeric, spaces, hyphens, underscores
    final validNameRegex = RegExp(r'^[a-zA-Z0-9\s\-_]+');
    return validNameRegex.hasMatch(name);
  }

  /// Creates a key pair with validation
  Future<QryptKEMKeyPair> generateValidatedKeyPair(
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
        final algorithm = keyPair.algorithm ?? 'Unknown';
        summary[algorithm] = (summary[algorithm] ?? 0) + 1;
      }

      return summary;
    } catch (e) {
      debugPrint('Error getting algorithm summary: $e');
      return {};
    }
  }

  /// Checks if the current KEM instance is healthy
  bool get isHealthy {
    if (_kem == null) return false;

    try {
      // Test basic functionality
      final testKeyPair = _kem!.generateKeyPair();
      final encResult = _kem!.encapsulate(testKeyPair.publicKey);
      final decResult = _kem!.decapsulate(
        encResult.ciphertext,
        testKeyPair.secretKey,
      );
      return _listsEqual(encResult.sharedSecret, decResult);
    } catch (e) {
      return false;
    }
  }

  /// Reinitializes the KEM instance if needed
  Future<void> ensureHealthy() async {
    if (!isHealthy) {
      dispose();
      _initializeKEM();
    }
  }
}
