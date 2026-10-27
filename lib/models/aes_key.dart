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

  /// Key length in bytes according to UTF-8 encoding
  int get byteLength => utf8.encode(key).length;

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
