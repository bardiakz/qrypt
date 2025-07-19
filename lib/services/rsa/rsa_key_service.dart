import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../models/rsa_key_pair.dart';

class RSAKeyService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyPairsKey = 'rsa_key_pairs';

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

  Future<void> saveKeyPair(RSAKeyPair keyPair) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.add(keyPair);

      final keyPairsJson = jsonEncode(
        keyPairs.map((kp) => kp.toJson()).toList(),
      );
      await _storage.write(key: _keyPairsKey, value: keyPairsJson);
    } catch (e) {
      print('Error saving key pair: $e');
      rethrow;
    }
  }

  Future<void> deleteKeyPair(String id) async {
    try {
      final keyPairs = await getKeyPairs();
      keyPairs.removeWhere((kp) => kp.id == id);

      final keyPairsJson = jsonEncode(
        keyPairs.map((kp) => kp.toJson()).toList(),
      );
      await _storage.write(key: _keyPairsKey, value: keyPairsJson);
    } catch (e) {
      print('Error deleting key pair: $e');
      rethrow;
    }
  }

  Future<RSAKeyPair> generateKeyPair(String name) async {
    // Generate RSA key pair (you'll need to implement actual RSA generation)
    // This is a placeholder - use a proper crypto library like pointycastle
    final publicKey = _generatePublicKey(); // Implement this
    final privateKey = _generatePrivateKey(); // Implement this

    return RSAKeyPair(
      id: const Uuid().v4(),
      name: name,
      publicKey: publicKey,
      privateKey: privateKey,
      createdAt: DateTime.now(),
    );
  }

  String _generatePublicKey() {
    // Implement actual RSA public key generation
    return "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----";
  }

  String _generatePrivateKey() {
    // Implement actual RSA private key generation
    return "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----";
  }

  bool validateKeyPair(String publicKey, String privateKey) {
    // Implement key validation logic
    return true; // Placeholder
  }
}
