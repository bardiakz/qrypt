import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrypt/models/custom_obfuscation_profile.dart';
import 'package:qrypt/resources/obfuscation/v2_map_pools.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/tag_manager.dart';

class CustomMapStorageService {
  CustomMapStorageService._();

  static final CustomMapStorageService instance = CustomMapStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'custom_v2_obfuscation_profiles';

  List<CustomObfuscationProfile> _cachedProfiles = [];
  bool _initialized = false;

  List<CustomObfuscationProfile> get profiles =>
      List.unmodifiable(_cachedProfiles);

  Future<List<CustomObfuscationProfile>> initialize() async {
    if (_initialized) return profiles;
    return await loadAll();
  }

  /// Loads all saved custom v2 profiles from secure storage.
  /// Accepts any structurally complete 17-entry map on load.
  Future<List<CustomObfuscationProfile>> loadAll() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.trim().isEmpty) {
        _cachedProfiles = [];
        _initialized = true;
        TagManager.updateCustomTags(_cachedProfiles);
        return profiles;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _cachedProfiles = [];
        _initialized = true;
        TagManager.updateCustomTags(_cachedProfiles);
        return profiles;
      }

      final list = <CustomObfuscationProfile>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final profile = CustomObfuscationProfile.fromStorageJson(item);
          if (profile != null) {
            list.add(profile);
          }
        }
      }

      _cachedProfiles = list;
      _initialized = true;
      TagManager.updateCustomTags(_cachedProfiles);
      return profiles;
    } catch (e) {
      debugPrint('Error loading custom obfuscation profiles: $e');
      _cachedProfiles = [];
      _initialized = true;
      TagManager.updateCustomTags(_cachedProfiles);
      return profiles;
    }
  }

  /// Saves a new custom map.
  /// Runs validateV2Map, deduplicates by content, checks collisions, and saves.
  Future<CustomObfuscationProfile> saveMap({
    required String name,
    required Map<String, String> map,
    int poolsVersion = kV2PoolsVersion,
    bool skipCollisionCheck = false,
  }) async {
    await initialize();

    // 1. Full v2 validation on save/import
    final problems = ObfuscationService.validateV2Map(map);
    if (problems.isNotEmpty) {
      throw FormatException('Invalid map rules:\n${problems.join('\n')}');
    }

    final newProfile = CustomObfuscationProfile(
      name: name,
      map: Map.unmodifiable(map),
      poolsVersion: poolsVersion,
    );

    // 2. Dedupe by map content
    for (final existing in _cachedProfiles) {
      if (existing.mapSignature == newProfile.mapSignature) {
        throw StateError(
          'A custom map with identical mappings already exists ("${existing.name}")',
        );
      }
    }

    // 3. Collision pre-flight check
    if (!skipCollisionCheck) {
      final collision = TagManager.checkCustomMapCollisions(map);
      if (collision != null) {
        throw StateError('Custom map tag collision detected: $collision');
      }
    }

    final updated = List<CustomObfuscationProfile>.from(_cachedProfiles)
      ..add(newProfile);

    await _persist(updated);
    _cachedProfiles = updated;
    TagManager.updateCustomTags(_cachedProfiles);

    return newProfile;
  }

  /// Deletes a saved custom map by ID.
  Future<void> deleteMap(String id) async {
    await initialize();
    final updated = _cachedProfiles.where((p) => p.id != id).toList();
    await _persist(updated);
    _cachedProfiles = updated;
    TagManager.updateCustomTags(_cachedProfiles);
  }

  /// Exports a single map profile to compact share JSON.
  String exportMap(CustomObfuscationProfile profile) {
    return const JsonEncoder.withIndent('  ').convert(profile.toShareJson());
  }

  /// Exports all saved maps as a single share bundle JSON.
  Future<String> exportAllMaps() async {
    await initialize();
    final bundle = {
      'v': 1,
      'maps': _cachedProfiles.map((p) => p.toShareJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  /// Imports a single map from share JSON or bundle JSON.
  Future<CustomObfuscationProfile> importMap(String jsonString) async {
    await initialize();
    final decoded = jsonDecode(jsonString.trim());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }

    if (decoded['maps'] is List) {
      final list = decoded['maps'] as List;
      if (list.isEmpty) {
        throw const FormatException('Bundle contains no maps');
      }
      return importMap(jsonEncode(list.first));
    }

    final profile = CustomObfuscationProfile.fromShareJson(decoded);
    return await saveMap(
      name: profile.name,
      map: profile.map,
      poolsVersion: profile.poolsVersion,
    );
  }

  /// Imports all maps from a bundle JSON or single share JSON.
  Future<List<CustomObfuscationProfile>> importAllMaps(String jsonString) async {
    await initialize();
    final decoded = jsonDecode(jsonString.trim());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }

    final imported = <CustomObfuscationProfile>[];

    if (decoded['maps'] is List) {
      final list = decoded['maps'] as List;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            final profile = CustomObfuscationProfile.fromShareJson(item);
            final saved = await saveMap(
              name: profile.name,
              map: profile.map,
              poolsVersion: profile.poolsVersion,
            );
            imported.add(saved);
          } catch (e) {
            debugPrint('Skipping invalid map in bundle: $e');
          }
        }
      }
    } else {
      final saved = await importMap(jsonString);
      imported.add(saved);
    }

    return imported;
  }

  Future<void> _persist(List<CustomObfuscationProfile> list) async {
    final raw = jsonEncode(list.map((p) => p.toStorageJson()).toList());
    await _storage.write(key: _storageKey, value: raw);
  }
}
