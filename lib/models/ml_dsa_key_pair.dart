import 'dart:convert';
import 'dart:typed_data';
import 'package:oqs/src/signature.dart';
import 'package:uuid/uuid.dart';

class QryptMLDSAKeyPair {
  final String id;
  final String name;
  final String algorithm;
  final Uint8List publicKey;
  final Uint8List secretKey;
  final String? description;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int usageCount;

  const QryptMLDSAKeyPair._({
    required this.id,
    required this.name,
    required this.algorithm,
    required this.publicKey,
    required this.secretKey,
    this.description,
    required this.createdAt,
    this.lastUsedAt,
    this.usageCount = 0,
  });

  /// Creates a new QryptMLDSAKeyPair from a SignatureKeyPair
  factory QryptMLDSAKeyPair.create({
    required String name,
    required SignatureKeyPair signatureKeyPair,
    required String algorithm,
    String? description,
  }) {
    return QryptMLDSAKeyPair._(
      id: const Uuid().v4(),
      name: name,
      algorithm: algorithm,
      publicKey: signatureKeyPair.publicKey,
      secretKey: signatureKeyPair.secretKey,
      description: description,
      createdAt: DateTime.now(),
      usageCount: 0,
    );
  }

  /// Creates a QryptMLDSAKeyPair from raw components
  factory QryptMLDSAKeyPair.fromComponents({
    String? id,
    required String name,
    required String algorithm,
    required Uint8List publicKey,
    required Uint8List secretKey,
    String? description,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int usageCount = 0,
  }) {
    return QryptMLDSAKeyPair._(
      id: id ?? const Uuid().v4(),
      name: name,
      algorithm: algorithm,
      publicKey: publicKey,
      secretKey: secretKey,
      description: description,
      createdAt: createdAt ?? DateTime.now(),
      lastUsedAt: lastUsedAt,
      usageCount: usageCount,
    );
  }

  /// Creates a QryptMLDSAKeyPair from JSON
  factory QryptMLDSAKeyPair.fromJson(Map<String, dynamic> json) {
    return QryptMLDSAKeyPair._(
      id: json['id'] as String,
      name: json['name'] as String,
      algorithm: json['algorithm'] as String,
      publicKey: base64Decode(json['publicKey'] as String),
      secretKey: base64Decode(json['secretKey'] as String),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
      usageCount: json['usageCount'] as int? ?? 0,
    );
  }

  /// Converts this QryptMLDSAKeyPair to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'algorithm': algorithm,
      'publicKey': base64Encode(publicKey),
      'secretKey': base64Encode(secretKey),
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'usageCount': usageCount,
    };
  }

  /// Returns the SignatureKeyPair for use with OQS operations
  SignatureKeyPair get signatureKeyPair {
    return SignatureKeyPair(publicKey: publicKey, secretKey: secretKey);
  }

  /// Gets the public key size in bytes
  int get publicKeySize => publicKey.length;

  /// Gets the secret key size in bytes
  int get secretKeySize => secretKey.length;

  /// Gets the total key pair size in bytes
  int get totalSize => publicKeySize + secretKeySize;

  /// Returns keys as base64 encoded strings
  Map<String, String> toStrings() {
    return {
      'publicKey': base64Encode(publicKey),
      'secretKey': base64Encode(secretKey),
    };
  }

  /// Returns keys as hex strings
  Map<String, String> toHexStrings() {
    return {
      'publicKey': publicKey
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      'secretKey': secretKey
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    };
  }
}
