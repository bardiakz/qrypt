import 'package:qrypt/resources/obfuscation/v2_map_pools.dart';
import 'package:qrypt/services/obfuscation/v2_map_generator.dart';
import 'package:uuid/uuid.dart';

class CustomObfuscationProfile {
  CustomObfuscationProfile({
    String? id,
    required this.name,
    required this.map,
    this.poolsVersion = kV2PoolsVersion,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final Map<String, String> map;
  final int poolsVersion;
  final DateTime createdAt;

  /// Canonical signature of the map content used for deduplication.
  String get mapSignature =>
      V2MapGenerator.symbols.map((s) => map[s] ?? '').join('|');

  /// Sanitize profile name: trim, remove control characters, clamp to 50 chars.
  static String sanitizeName(String? raw) {
    if (raw == null) return 'Custom Map';
    final cleaned = raw
        .replaceAll(RegExp(r'[\r\n\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'Custom Map';
    if (cleaned.length > 50) return cleaned.substring(0, 50).trim();
    return cleaned;
  }

  /// Compact share format: {"v": 1, "n": name, "m": [17 values in 0-9,a-f,: order]}
  Map<String, dynamic> toShareJson() {
    return {
      'v': 1,
      'n': sanitizeName(name),
      'm': [
        for (final s in V2MapGenerator.symbols) map[s] ?? '',
      ],
    };
  }

  /// Parse from compact share format.
  factory CustomObfuscationProfile.fromShareJson(
    Map<String, dynamic> json, {
    String? id,
    int? poolsVersion,
  }) {
    final version = json['v'];
    if (version != 1) {
      throw FormatException('Unsupported share format version: $version');
    }

    final rawName = json['n'];
    final name = sanitizeName(rawName is String ? rawName : null);

    final rawList = json['m'];
    if (rawList is! List || rawList.length != V2MapGenerator.symbols.length) {
      throw FormatException(
        'Invalid map entries: expected ${V2MapGenerator.symbols.length} values',
      );
    }

    final map = <String, String>{};
    for (var i = 0; i < V2MapGenerator.symbols.length; i++) {
      final val = rawList[i];
      if (val is! String || val.isEmpty) {
        throw FormatException('Invalid entry for "${V2MapGenerator.symbols[i]}"');
      }
      map[V2MapGenerator.symbols[i]] = val;
    }

    return CustomObfuscationProfile(
      id: id,
      name: name,
      map: Map.unmodifiable(map),
      poolsVersion: poolsVersion ?? kV2PoolsVersion,
    );
  }

  /// Full persistence format for secure storage.
  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'name': sanitizeName(name),
      'map': map,
      'poolsVersion': poolsVersion,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Deserializes from storage, accepting any structurally complete 17-entry map.
  static CustomObfuscationProfile? fromStorageJson(Map<String, dynamic> json) {
    try {
      final rawMap = json['map'];
      if (rawMap is! Map) return null;

      final parsedMap = <String, String>{};
      for (final s in V2MapGenerator.symbols) {
        final val = rawMap[s];
        if (val is! String || val.isEmpty) {
          return null; // Structurally incomplete
        }
        parsedMap[s] = val;
      }

      final rawName = json['name'] as String?;
      final name = sanitizeName(rawName);
      final id = (json['id'] as String?) ?? const Uuid().v4();
      final poolsVersion = (json['poolsVersion'] as int?) ?? kV2PoolsVersion;
      final createdAt = json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now();

      return CustomObfuscationProfile(
        id: id,
        name: name,
        map: Map.unmodifiable(parsedMap),
        poolsVersion: poolsVersion,
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }
}
