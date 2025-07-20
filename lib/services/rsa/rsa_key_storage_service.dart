import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../models/rsa_key_pair.dart';

class RSAKeyStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyPairsKey = 'rsa_key_pairs';

  /// Retrieves all stored RSA key pairs
  Future<List<RSAKeyPair>> getKeyPairs() async {
    try {
      final String? keyPairsJson = await _storage.read(key: _keyPairsKey);
      if (keyPairsJson == null) return [];

      final List<dynamic> keyPairsList = jsonDecode(keyPairsJson);
      return keyPairsList.map((json) => RSAKeyPair.fromJson(json)).toList();
    } catch (e) {
      print('Error loading key pairs: $e');
      return [];
    }
  }

  /// Saves a single RSA key pair to storage
  Future<void> saveKeyPair(RSAKeyPair keyPair) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.add(keyPair);
      await _saveKeyPairsList(keyPairs);
    } catch (e) {
      print('Error saving key pair: $e');
      rethrow;
    }
  }

  /// Deletes an RSA key pair by ID
  Future<void> deleteKeyPair(String id) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.removeWhere((kp) => kp.id == id);
      await _saveKeyPairsList(keyPairs);
    } catch (e) {
      print('Error deleting key pair: $e');
      rethrow;
    }
  }

  /// Updates an existing RSA key pair
  Future<void> updateKeyPair(RSAKeyPair updatedKeyPair) async {
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
      print('Error updating key pair: $e');
      rethrow;
    }
  }

  /// Retrieves a specific RSA key pair by ID
  Future<RSAKeyPair?> getKeyPairById(String id) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.firstWhere(
        (kp) => kp.id == id,
        orElse: () => throw StateError('Key pair not found'),
      );
    } catch (e) {
      print('Error getting key pair by ID: $e');
      return null;
    }
  }

  /// Checks if a key pair with the given ID exists
  Future<bool> keyPairExists(String id) async {
    try {
      final keyPair = await getKeyPairById(id);
      return keyPair != null;
    } catch (e) {
      return false;
    }
  }

  /// Gets the count of stored key pairs
  Future<int> getKeyPairsCount() async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.length;
    } catch (e) {
      print('Error getting key pairs count: $e');
      return 0;
    }
  }

  /// Checks if a key pair with the given name already exists
  Future<bool> keyPairNameExists(String name) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs.any((kp) => kp.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      print('Error checking key pair name: $e');
      return false;
    }
  }

  /// Gets key pairs filtered by name (case-insensitive search)
  Future<List<RSAKeyPair>> searchKeyPairsByName(String searchTerm) async {
    try {
      final keyPairs = await getKeyPairs();
      return keyPairs
          .where(
            (kp) => kp.name.toLowerCase().contains(searchTerm.toLowerCase()),
          )
          .toList();
    } catch (e) {
      print('Error searching key pairs: $e');
      return [];
    }
  }

  /// Gets key pairs sorted by creation date (newest first)
  Future<List<RSAKeyPair>> getKeyPairsSortedByDate({
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
      print('Error sorting key pairs: $e');
      return [];
    }
  }

  /// Clears all stored key pairs
  Future<void> clearAllKeyPairs() async {
    try {
      await _storage.delete(key: _keyPairsKey);
    } catch (e) {
      print('Error clearing key pairs: $e');
      rethrow;
    }
  }

  /// Exports all key pairs as JSON string
  Future<String> exportKeyPairs() async {
    try {
      final keyPairs = await getKeyPairs();
      return jsonEncode(keyPairs.map((kp) => kp.toJson()).toList());
    } catch (e) {
      print('Error exporting key pairs: $e');
      rethrow;
    }
  }

  /// Imports key pairs from JSON string
  Future<void> importKeyPairs(
    String keyPairsJson, {
    bool replaceExisting = false,
  }) async {
    try {
      final List<dynamic> importedList = jsonDecode(keyPairsJson);
      final importedKeyPairs = importedList
          .map((json) => RSAKeyPair.fromJson(json))
          .toList();

      List<RSAKeyPair> finalKeyPairs;
      if (replaceExisting) {
        finalKeyPairs = importedKeyPairs;
      } else {
        final existingKeyPairs = await getKeyPairs();
        finalKeyPairs = [...existingKeyPairs, ...importedKeyPairs];
      }

      await _saveKeyPairsList(finalKeyPairs);
    } catch (e) {
      print('Error importing key pairs: $e');
      rethrow;
    }
  }

  /// Private helper method to save the complete list of key pairs
  Future<void> _saveKeyPairsList(List<RSAKeyPair> keyPairs) async {
    try {
      final keyPairsJson = jsonEncode(
        keyPairs.map((kp) => kp.toJson()).toList(),
      );
      await _storage.write(key: _keyPairsKey, value: keyPairsJson);
    } catch (e) {
      print('Error saving key pairs list: $e');
      rethrow;
    }
  }

  /// Gets storage size information (approximate)
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final keyPairs = await getKeyPairs();
      final keyPairsJson = jsonEncode(
        keyPairs.map((kp) => kp.toJson()).toList(),
      );

      return {
        'keyPairsCount': keyPairs.length,
        'approximateStorageSize': keyPairsJson.length, // bytes
        'averageKeyPairSize': keyPairs.isEmpty
            ? 0
            : keyPairsJson.length ~/ keyPairs.length,
      };
    } catch (e) {
      print('Error getting storage info: $e');
      return {
        'keyPairsCount': 0,
        'approximateStorageSize': 0,
        'averageKeyPairSize': 0,
      };
    }
  }
}
