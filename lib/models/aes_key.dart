import 'dart:convert';

class AESKey {
  final String id;
  final String name;
  final String key;
  final DateTime createdAt;

  AESKey({
    required this.id,
    required this.name,
    required this.key,
    required this.createdAt,
  });

  /// Sentinel representing explicit selection of manual/custom key entry
  static final custom = AESKey(
    id: 'custom-manual-input',
    name: 'Custom / Manual Input',
    key: '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Whether this key represents manual custom input rather than a stored key
  bool get isCustom => id == 'custom-manual-input';

  /// Key length in bytes (recognizes 24-char Base64 as 16 bytes, 48-char Hex
  /// as 24 bytes, and 44-char Base64 / 64-char Hex as 32 bytes)
  int get byteLength {
    final trimmed = key.trim();
    if (trimmed.length == 24 && trimmed.endsWith('==')) {
      try {
        final decoded = base64.decode(trimmed);
        if (decoded.length == 16) return 16;
      } catch (_) {}
    }
    if (trimmed.length == 48 && RegExp(r'^[0-9a-fA-F]{48}$').hasMatch(trimmed)) {
      return 24;
    }
    if (trimmed.length == 44) {
      try {
        final decoded = base64.decode(trimmed);
        if (decoded.length == 32) return 32;
      } catch (_) {}
    }
    if (trimmed.length == 64 && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmed)) {
      return 32;
    }
    return utf8.encode(trimmed).length;
  }

  /// Key length in bits
  int get bitLength => byteLength * 8;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'key': key,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AESKey.fromJson(Map<String, dynamic> json) => AESKey(
    id: json['id'] as String,
    name: json['name'] as String,
    key: json['key'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  AESKey copyWith({
    String? id,
    String? name,
    String? key,
    DateTime? createdAt,
  }) {
    return AESKey(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'AESKey(id: $id, name: $name, createdAt: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AESKey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
