import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:qrypt/models/ml_dsa_key_pair.dart';

class MlDsaKeyStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyPairsKey = 'mldsa_key_pairs';

  /// Retrieves all stored ML-DSA key pairs
  Future<List<QryptMLDSAKeyPair>> getKeyPairs() async {
    try {
      final String? keyPairsJson = await _storage.read(key: _keyPairsKey);
      if (keyPairsJson == null) return [];

      final List<dynamic> keyPairsList = jsonDecode(keyPairsJson);
      return keyPairsList
          .map((json) => QryptMLDSAKeyPair.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading ML-DSA key pairs: $e');
      return [];
    }
  }

  /// Saves a single ML-DSA key pair to storage
  Future<void> saveKeyPair(QryptMLDSAKeyPair keyPair) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.add(keyPair);
      await _saveKeyPairsList(keyPairs);
    } catch (e) {
      debugPrint('Error saving ML-DSA key pair: $e');
      rethrow;
    }
  }

  /// Deletes a ML-DSA key pair by ID
  Future<void> deleteKeyPair(String id) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.removeWhere((kp) => kp.id == id);
      await _saveKeyPairsList(keyPairs);
    } catch (e) {
      debugPrint('Error deleting ML-DSA key pair: $e');
      rethrow;
    }
  }

  /// Updates an existing ML-DSA key pair
  Future<void> updateKeyPair(QryptMLDSAKeyPair updatedKeyPair) async {
    try {
      final keyPairs = await getKeyPairs();
      final index = keyPairs.indexWhere((kp) => kp.id == updatedKeyPair.id);

      if (index != -1) {
        keyPairs[index] = updatedKeyPair;
        await _saveKeyPairsList(keyPairs);
      } else {
        throw Exception(
          'ML-DSA key pair with ID ${updatedKeyPair.id} not found',
        );
      }
    } catch (e) {
      debugPrint('Error updating ML-DSA key pair: $e');
      rethrow;
    }
  }

  /// Retrieves a specific ML-DSA key pair by ID
  Future<QryptMLDSAKeyPair?> getKeyPairById(String id) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.firstWhere(
        (kp) => kp.id == id,
        orElse: () => throw StateError('ML-DSA key pair not found'),
      );
    } catch (e) {
      debugPrint('Error getting ML-DSA key pair by ID: $e');
      return null;
    }
  }

  /// Checks if a ML-DSA key pair with the given name already exists
  Future<bool> keyPairNameExists(String name) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.any((kp) => kp.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      debugPrint('Error checking ML-DSA key pair name: $e');
      return false;
    }
  }

  /// Gets ML-DSA key pairs filtered by name (case-insensitive search)
  Future<List<QryptMLDSAKeyPair>> searchKeyPairsByName(
    String searchTerm,
  ) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs
          .where(
            (kp) => kp.name.toLowerCase().contains(searchTerm.toLowerCase()),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching ML-DSA key pairs: $e');
      return [];
    }
  }

  /// Gets ML-DSA key pairs filtered by algorithm
  Future<List<QryptMLDSAKeyPair>> getKeyPairsByAlgorithm(
    String algorithm,
  ) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.where((kp) => kp.algorithm == algorithm).toList();
    } catch (e) {
      debugPrint('Error filtering ML-DSA key pairs by algorithm: $e');
      return [];
    }
  }

  /// Gets all unique algorithms used in stored key pairs
  Future<List<String>> getUsedAlgorithms() async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.map((kp) => kp.algorithm).toSet().toList()..sort();
    } catch (e) {
      debugPrint('Error getting used algorithms: $e');
      return [];
    }
  }

  /// Clears all stored ML-DSA key pairs
  Future<void> clearAllKeyPairs() async {
    try {
      await _storage.delete(key: _keyPairsKey);
    } catch (e) {
      debugPrint('Error clearing all ML-DSA key pairs: $e');
      rethrow;
    }
  }

  /// Gets storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
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
      debugPrint('Error getting ML-DSA storage stats: $e');
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

  /// Private helper method to save the complete list of key pairs
  Future<void> _saveKeyPairsList(List<QryptMLDSAKeyPair> keyPairs) async {
    try {
      final keyPairsJson = jsonEncode(
        keyPairs.map((kp) => kp.toJson()).toList(),
      );
      await _storage.write(key: _keyPairsKey, value: keyPairsJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving ML-DSA key pairs list: $e');
      }
      rethrow;
    }
  }
}
