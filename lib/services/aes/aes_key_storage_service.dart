import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../models/aes_key.dart';
import '../../resources/global_resources.dart';

class AesKeyStorageService {
  final FlutterSecureStorage _storage;
  static const String _keysKey = 'aes_keys';

  const AesKeyStorageService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  /// Retrieves all stored AES keys
  Future<List<AESKey>> getKeys() async {
    try {
      final String? keysJson = await _storage.read(key: _keysKey);
      if (keysJson == null) return [];

      final List<dynamic> keysList = jsonDecode(keysJson);
      return keysList
          .map((json) => AESKey.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading AES keys: $e');
      return [];
    }
  }

  /// Saves a single AES key to storage
  Future<void> saveKey(AESKey key) async {
    try {
      final keys = await getKeys();
      // Replace if existing with same id, else add
      final index = keys.indexWhere((k) => k.id == key.id);
      if (index != -1) {
        keys[index] = key;
      } else {
        keys.add(key);
      }
      await _saveKeysList(keys);
    } catch (e) {
      debugPrint('Error saving AES key: $e');
      rethrow;
    }
  }

  /// Deletes an AES key by ID
  Future<void> deleteKey(String id) async {
    try {
      final keys = await getKeys();
      keys.removeWhere((k) => k.id == id);
      await _saveKeysList(keys);
    } catch (e) {
      debugPrint('Error deleting AES key: $e');
      rethrow;
    }
  }

  /// Updates an existing AES key
  Future<void> updateKey(AESKey updatedKey) async {
    try {
      final keys = await getKeys();
      final index = keys.indexWhere((k) => k.id == updatedKey.id);

      if (index != -1) {
        keys[index] = updatedKey;
        await _saveKeysList(keys);
      } else {
        throw Exception('AES key with ID ${updatedKey.id} not found');
      }
    } catch (e) {
      debugPrint('Error updating AES key: $e');
      rethrow;
    }
  }

  /// Retrieves an AES key by ID
  Future<AESKey?> getKeyById(String id) async {
    try {
      final keys = await getKeys();
      return keys.firstWhere((k) => k.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Generates and creates a new AESKey instance
  AESKey createRandomKey({required String name, int length = 32}) {
    return AESKey(
      id: const Uuid().v4(),
      name: name,
      key: generateRandomAesKey(length: length),
      createdAt: DateTime.now(),
    );
  }

  /// Deletes all stored AES keys
  Future<void> clearAllKeys() async {
    try {
      await _storage.delete(key: _keysKey);
    } catch (e) {
      debugPrint('Error clearing AES keys: $e');
      rethrow;
    }
  }

  /// Helper method to save the list of keys to storage
  Future<void> _saveKeysList(List<AESKey> keys) async {
    final String keysJson = jsonEncode(keys.map((k) => k.toJson()).toList());
    await _storage.write(key: _keysKey, value: keysJson);
  }
}
