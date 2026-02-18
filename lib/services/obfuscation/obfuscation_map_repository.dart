import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/obfuscation_profile.dart';
import 'package:qrypt/resources/obfuscation/built_in_obfuscation_maps.dart';

class ObfuscationMapRepository {
  ObfuscationMapRepository._();

  static final ObfuscationMapRepository instance = ObfuscationMapRepository._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _customProfilesKey = 'custom_obfuscation_profiles_v1';

  final Map<ObfuscationMethod, Map<String, String>> _resolvedMaps =
      <ObfuscationMethod, Map<String, String>>{};

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await reload();
  }

  Future<void> reload() async {
    _resolvedMaps.clear();

    for (final method in _mappedMethods) {
      _resolvedMaps[method] = builtInMapForMethod(method);
    }

    final customProfiles = await _readCustomProfiles();
    for (final profile in customProfiles) {
      final method = _methodFromProfileId(profile.id);
      if (method == null) continue;

      try {
        final sanitized = sanitizeMap(profile.map);
        if (sanitized.isNotEmpty) {
          _resolvedMaps[method] = sanitized;
        }
      } catch (e) {
        debugPrint('Invalid custom obfuscation profile "${profile.id}": $e');
      }
    }

    _initialized = true;
  }

  Map<String, String> getMap(ObfuscationMethod method) {
    if (!_mappedMethods.contains(method)) {
      return <String, String>{};
    }

    return Map<String, String>.unmodifiable(
      _resolvedMaps[method] ?? builtInMapForMethod(method),
    );
  }

  Map<String, String> getBuiltInMap(ObfuscationMethod method) {
    if (!_mappedMethods.contains(method)) {
      return <String, String>{};
    }
    return Map<String, String>.unmodifiable(builtInMapForMethod(method));
  }

  Future<void> setCustomMap(
    ObfuscationMethod method,
    Map<String, String> map,
  ) async {
    _assertSupportedMethod(method);

    final sanitized = sanitizeMap(map);
    if (sanitized.isEmpty) {
      throw ArgumentError('Custom map cannot be empty');
    }

    final profileId = _profileIdForMethod(method);
    final profiles = await _readCustomProfiles();

    final updated = ObfuscationProfile(
      id: profileId,
      displayName: _displayNameForMethod(method),
      map: sanitized,
      isBuiltIn: false,
      updatedAt: DateTime.now(),
    );

    final nextProfiles = <ObfuscationProfile>[];
    var replaced = false;

    for (final profile in profiles) {
      if (profile.id == profileId) {
        nextProfiles.add(updated);
        replaced = true;
      } else {
        nextProfiles.add(profile);
      }
    }

    if (!replaced) {
      nextProfiles.add(updated);
    }

    await _writeCustomProfiles(nextProfiles);
    _resolvedMaps[method] = sanitized;
    _initialized = true;
  }

  Future<void> clearCustomMap(ObfuscationMethod method) async {
    _assertSupportedMethod(method);

    final profileId = _profileIdForMethod(method);
    final profiles = await _readCustomProfiles();
    final filtered = profiles.where((p) => p.id != profileId).toList();

    await _writeCustomProfiles(filtered);
    _resolvedMaps[method] = builtInMapForMethod(method);
    _initialized = true;
  }

  Future<Map<String, String>?> getCustomMap(ObfuscationMethod method) async {
    _assertSupportedMethod(method);

    final profileId = _profileIdForMethod(method);
    final profiles = await _readCustomProfiles();

    for (final profile in profiles) {
      if (profile.id == profileId) {
        final sanitized = sanitizeMap(profile.map);
        return Map<String, String>.unmodifiable(sanitized);
      }
    }

    return null;
  }

  List<ObfuscationMethod> get _mappedMethods => const [
    ObfuscationMethod.en1,
    ObfuscationMethod.en2,
    ObfuscationMethod.fa1,
    ObfuscationMethod.fa2,
  ];

  String _profileIdForMethod(ObfuscationMethod method) => method.name;

  ObfuscationMethod? _methodFromProfileId(String profileId) {
    try {
      final method = ObfuscationMethod.values.firstWhere(
        (e) => e.name == profileId,
      );
      if (_mappedMethods.contains(method)) {
        return method;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _displayNameForMethod(ObfuscationMethod method) {
    switch (method) {
      case ObfuscationMethod.en1:
        return 'EN1 (Character-based)';
      case ObfuscationMethod.en2:
        return 'EN2 (Word-based)';
      case ObfuscationMethod.fa1:
        return 'FA1 (Character-based)';
      case ObfuscationMethod.fa2:
        return 'FA2 (Word-based)';
      default:
        return method.name;
    }
  }

  void _assertSupportedMethod(ObfuscationMethod method) {
    if (!_mappedMethods.contains(method)) {
      throw ArgumentError('Custom map is not supported for method: $method');
    }
  }

  Future<List<ObfuscationProfile>> _readCustomProfiles() async {
    try {
      final raw = await _storage.read(key: _customProfilesKey);
      if (raw == null || raw.trim().isEmpty) {
        return <ObfuscationProfile>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <ObfuscationProfile>[];
      }

      final profiles = <ObfuscationProfile>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          profiles.add(ObfuscationProfile.fromJson(item));
        } else if (item is Map) {
          profiles.add(
            ObfuscationProfile.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }

      return profiles;
    } catch (e) {
      debugPrint('Failed to read custom obfuscation profiles: $e');
      return <ObfuscationProfile>[];
    }
  }

  Future<void> _writeCustomProfiles(List<ObfuscationProfile> profiles) async {
    final payload = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _storage.write(key: _customProfilesKey, value: payload);
  }

  static Map<String, String> sanitizeMap(Map<String, String> input) {
    if (input.isEmpty) {
      return <String, String>{};
    }

    final sanitized = <String, String>{};

    input.forEach((rawKey, rawValue) {
      final key = rawKey;
      final value = rawValue.trim();

      if (key.isEmpty) {
        throw ArgumentError('Map key cannot be empty');
      }
      if (value.isEmpty) {
        throw ArgumentError('Map value cannot be empty for key "$key"');
      }
      if (RegExp(r'\s').hasMatch(value)) {
        throw ArgumentError(
          'Map value for key "$key" cannot include whitespace',
        );
      }

      sanitized[key] = value;
    });

    final seenValues = <String>{};
    for (final entry in sanitized.entries) {
      if (!seenValues.add(entry.value)) {
        throw ArgumentError(
          'Duplicate map value "${entry.value}" is not allowed',
        );
      }
    }

    return sanitized;
  }
}
