import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../../models/kem_key_pair.dart';

class KemKeyStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyPairsKey = 'kem_key_pairs';

  /// Retrieves all stored KEM key pairs
  Future<List<QryptKEMKeyPair>> getKeyPairs() async {
    try {
      final String? keyPairsJson = await _storage.read(key: _keyPairsKey);
      if (keyPairsJson == null) return [];

      final List<dynamic> keyPairsList = jsonDecode(keyPairsJson);
      return keyPairsList
          .map((json) => QryptKEMKeyPair.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading key pairs: $e');
      return [];
    }
  }

  /// Saves a single KEM key pair to storage
  Future<void> saveKeyPair(QryptKEMKeyPair keyPair) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.add(keyPair);
      await _saveKeyPairsList(keyPairs);
    } catch (e) {
      debugPrint('Error saving key pair: $e');
      rethrow;
    }
  }

  /// Deletes a KEM key pair by ID
  Future<void> deleteKeyPair(String id) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.removeWhere((kp) => kp.id == id);
      await _saveKeyPairsList(keyPairs);
    } catch (e) {
      debugPrint('Error deleting key pair: $e');
      rethrow;
    }
  }

  /// Updates an existing KEM key pair
  Future<void> updateKeyPair(QryptKEMKeyPair updatedKeyPair) async {
    try {
      final keyPairs = await getKeyPairs();
      final index = keyPairs.indexWhere((kp) => kp.id == updatedKeyPair.id);

      if (index != -1) {
        keyPairs[index] = updatedKeyPair;
        await _saveKeyPairsList(keyPairs);
      } else {
        throw Exception('Key pair with ID ${updatedKeyPair.id} not found');
      }
    } catch (e) {
      debugPrint('Error updating key pair: $e');
      rethrow;
    }
  }

  /// Retrieves a specific KEM key pair by ID
  Future<QryptKEMKeyPair?> getKeyPairById(String id) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.firstWhere(
        (kp) => kp.id == id,
        orElse: () => throw StateError('Key pair not found'),
      );
    } catch (e) {
      debugPrint('Error getting key pair by ID: $e');
      return null;
    }
  }

  /// Checks if a key pair with the given name already exists
  Future<bool> keyPairNameExists(String name) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.any((kp) => kp.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      debugPrint('Error checking key pair name: $e');
      return false;
    }
  }

  /// Gets key pairs filtered by name (case-insensitive search)
  Future<List<QryptKEMKeyPair>> searchKeyPairsByName(String searchTerm) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs
          .where(
            (kp) => kp.name.toLowerCase().contains(searchTerm.toLowerCase()),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching key pairs: $e');
      return [];
    }
  }

  /// Private helper method to save the complete list of key pairs
  Future<void> _saveKeyPairsList(List<QryptKEMKeyPair> keyPairs) async {
    try {
      final keyPairsJson = jsonEncode(
        keyPairs.map((kp) => kp.toJson()).toList(),
      );
      await _storage.write(key: _keyPairsKey, value: keyPairsJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving key pairs list: $e');
      }
      rethrow;
    }
  }
}
