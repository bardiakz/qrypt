import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/compression_method.dart';
import '../../models/sign_method.dart';

// Storage service for persisting settings
class SettingsStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _defaultEncryptionKey = 'default_encryption_method';
  static const String _defaultObfuscationKey = 'default_obfuscation_method';
  static const String _defaultCompressionKey = 'default_compression_method';
  static const String _defaultSignKey = 'default_sign_method';

  static Future<EncryptionMethod> getDefaultEncryptionMethod() async {
    try {
      final value = await _storage.read(key: _defaultEncryptionKey);
      if (value != null) {
        return EncryptionMethod.values.firstWhere(
          (e) => e.name == value,
          orElse: () => EncryptionMethod.aesGcm,
        );
      }
    } catch (e) {}
    return EncryptionMethod.aesGcm;
  }

  static Future<void> setDefaultEncryptionMethod(
    EncryptionMethod method,
  ) async {
    await _storage.write(key: _defaultEncryptionKey, value: method.name);
  }

  static Future<ObfuscationMethod> getDefaultObfuscationMethod() async {
    try {
      final value = await _storage.read(key: _defaultObfuscationKey);
      if (value != null) {
        return ObfuscationMethod.values.firstWhere(
          (e) => e.name == value,
          orElse: () => ObfuscationMethod.en2,
        );
      }
    } catch (e) {}
    return ObfuscationMethod.en2;
  }

  static Future<void> setDefaultObfuscationMethod(
    ObfuscationMethod method,
  ) async {
    await _storage.write(key: _defaultObfuscationKey, value: method.name);
  }

  static Future<CompressionMethod> getDefaultCompressionMethod() async {
    try {
      final value = await _storage.read(key: _defaultCompressionKey);
      if (value != null) {
        return CompressionMethod.values.firstWhere(
          (e) => e.name == value,
          orElse: () => CompressionMethod.brotli,
        );
      }
    } catch (e) {}
    return CompressionMethod.brotli;
  }

  static Future<void> setDefaultCompressionMethod(
    CompressionMethod method,
  ) async {
    await _storage.write(key: _defaultCompressionKey, value: method.name);
  }

  static Future<SignMethod> getDefaultSignMethod() async {
    try {
      final value = await _storage.read(key: _defaultSignKey);
      if (value != null) {
        return SignMethod.values.firstWhere(
          (e) => e.name == value,
          orElse: () => SignMethod.none,
        );
      }
    } catch (e) {}
    return SignMethod.none;
  }

  static Future<void> setDefaultSignMethod(SignMethod method) async {
    await _storage.write(key: _defaultSignKey, value: method.name);
  }
}

// State notifier for managing default encryption settings
class DefaultEncryptionSettingsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  DefaultEncryptionSettingsNotifier() : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final encryption =
          await SettingsStorageService.getDefaultEncryptionMethod();
      final obfuscation =
          await SettingsStorageService.getDefaultObfuscationMethod();
      final compression =
          await SettingsStorageService.getDefaultCompressionMethod();
      final sign = await SettingsStorageService.getDefaultSignMethod();

      state = AsyncValue.data({
        'encryption': encryption,
        'obfuscation': obfuscation,
        'compression': compression,
        'sign': sign,
      });
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> setDefaultEncryption(EncryptionMethod method) async {
    try {
      await SettingsStorageService.setDefaultEncryptionMethod(method);
      await _loadSettings(); // Reload to ensure consistency
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> setDefaultObfuscation(ObfuscationMethod method) async {
    try {
      await SettingsStorageService.setDefaultObfuscationMethod(method);
      await _loadSettings();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> setDefaultCompression(CompressionMethod method) async {
    try {
      await SettingsStorageService.setDefaultCompressionMethod(method);
      await _loadSettings();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> setDefaultSign(SignMethod method) async {
    try {
      await SettingsStorageService.setDefaultSignMethod(method);
      await _loadSettings();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}
