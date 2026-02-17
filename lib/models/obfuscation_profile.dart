class ObfuscationProfile {
  ObfuscationProfile({
    required this.id,
    required this.displayName,
    required this.map,
    this.isBuiltIn = false,
    this.updatedAt,
  });

  final String id;
  final String displayName;
  final Map<String, String> map;
  final bool isBuiltIn;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'isBuiltIn': isBuiltIn,
      'updatedAt': updatedAt?.toIso8601String(),
      'map': map,
    };
  }

  factory ObfuscationProfile.fromJson(Map<String, dynamic> json) {
    return ObfuscationProfile(
      id: json['id'] as String,
      displayName: (json['displayName'] as String?) ?? (json['id'] as String),
      isBuiltIn: (json['isBuiltIn'] as bool?) ?? false,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      map: Map<String, String>.from(
        (json['map'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }
}
