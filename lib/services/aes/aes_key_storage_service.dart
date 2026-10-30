import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../models/aes_key.dart';
import '../../resources/global_resources.dart';

class AesKeyStorageService {
  final FlutterSecureStorage _storage;
  static const String _keysKey = 'aes_keys';
  static const String _lastUsedKeyIdKey = 'aes_last_used_key_id';

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

  /// Saves a single AES key to storage with write-then-read verification
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

      // Write-then-read verification invariant
      final verifiedKeys = await getKeys();
      if (!verifiedKeys.any((k) => k.id == key.id && k.key == key.key)) {
        throw StateError(
          'Secure storage write verification failed for AES key "${key.name}"',
        );
      }
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

      final lastUsed = await getLastUsedKeyId();
      if (lastUsed == id) {
        await _storage.delete(key: _lastUsedKeyIdKey);
      }
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

  /// Gets the ID of the last successfully used AES key
  Future<String?> getLastUsedKeyId() async {
    try {
      return await _storage.read(key: _lastUsedKeyIdKey);
    } catch (e) {
      debugPrint('Error reading last used AES key ID: $e');
      return null;
    }
  }

  /// Records the ID of the last successfully used AES key
  Future<void> setLastUsedKeyId(String id) async {
    try {
      await _storage.write(key: _lastUsedKeyIdKey, value: id);
    } catch (e) {
      debugPrint('Error recording last used AES key ID: $e');
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
      await _storage.delete(key: _lastUsedKeyIdKey);
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
