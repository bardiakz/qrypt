import 'package:oqs/oqs.dart';
import 'dart:typed_data';
import 'dart:convert';

class QryptKEMKeyPair {
  final String id;
  final String name;
  final KEMKeyPair kemKeyPair;
  final DateTime createdAt;
  final String? description;
  final String? algorithm;

  const QryptKEMKeyPair({
    required this.id,
    required this.name,
    required this.kemKeyPair,
    required this.createdAt,
    this.description,
    this.algorithm,
  });

  /// Create a QryptKEMKeyPair with auto-generated ID and current timestamp
  factory QryptKEMKeyPair.create({
    required String name,
    required KEMKeyPair kemKeyPair,
    String? description,
    String? algorithm,
  }) {
    return QryptKEMKeyPair(
      id: _generateId(),
      name: name,
      kemKeyPair: kemKeyPair,
      createdAt: DateTime.now(),
      description: description,
      algorithm: algorithm,
    );
  }

  /// Convenience getters that delegate to the wrapped KEMKeyPair
  Uint8List get publicKey => kemKeyPair.publicKey;
  Uint8List get secretKey => kemKeyPair.secretKey;
  int get publicKeySize => publicKey.length;
  int get secretKeySize => secretKey.length;

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'publicKey': base64Encode(kemKeyPair.publicKey),
      'secretKey': base64Encode(kemKeyPair.secretKey),
      'createdAt': createdAt.toIso8601String(),
      'description': description,
      'algorithm': algorithm,
    };
  }

  /// Create from JSON
  factory QryptKEMKeyPair.fromJson(Map<String, dynamic> json) {
    final publicKey = base64Decode(json['publicKey'] as String);
    final secretKey = base64Decode(json['secretKey'] as String);

    return QryptKEMKeyPair(
      id: json['id'] as String,
      name: json['name'] as String,
      kemKeyPair: KEMKeyPair(publicKey: publicKey, secretKey: secretKey),
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
      algorithm: json['algorithm'] as String?,
    );
  }

  /// Create a copy with updated fields
  QryptKEMKeyPair copyWith({
    String? id,
    String? name,
    KEMKeyPair? kemKeyPair,
    DateTime? createdAt,
    String? description,
    String? algorithm,
  }) {
    return QryptKEMKeyPair(
      id: id ?? this.id,
      name: name ?? this.name,
      kemKeyPair: kemKeyPair ?? this.kemKeyPair,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      algorithm: algorithm ?? this.algorithm,
    );
  }

  String get displayName => name.isNotEmpty ? name : 'Key Pair $id';

  static String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 31) % 1000000;
    return 'kem_${timestamp}_$random';
  }

  @override
  String toString() {
    return 'QryptKEMKeyPair(id: $id, name: $name, algorithm: $algorithm, '
        'publicKeySize: ${publicKey.length}, secretKeySize: ${secretKey.length}, '
        'createdAt: $createdAt)';
  }
}
