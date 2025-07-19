class RSAKeyPair {
  final String id;
  final String name;
  final String publicKey;
  final String privateKey;
  final DateTime createdAt;

  RSAKeyPair({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.privateKey,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'publicKey': publicKey,
    'privateKey': privateKey,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RSAKeyPair.fromJson(Map<String, dynamic> json) => RSAKeyPair(
    id: json['id'],
    name: json['name'],
    publicKey: json['publicKey'],
    privateKey: json['privateKey'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}
