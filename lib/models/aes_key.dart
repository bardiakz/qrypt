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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AESKey && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
