import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/screen_security_service.dart';
import 'package:qrypt/services/secure_storage_config.dart';
import '../../models/compression_method.dart';
import '../../models/sign_method.dart';

// Storage service for persisting settings
class SettingsStorageService {
  static const FlutterSecureStorage _storage = qryptSecureStorage;

  static const String _defaultEncryptionKey = 'default_encryption_method';
  static const String _defaultObfuscationKey = 'default_obfuscation_method';
  static const String _defaultCompressionKey = 'default_compression_method';
  static const String _defaultSignKey = 'default_sign_method';
  static const String _disclaimerAcceptedKey = 'disclaimer_accepted_v1';
  static const String _screenSecurityKey = 'android_flag_secure_enabled';
  static const String _sensitiveClipboardProtectionKey =
      'sensitive_clipboard_protection_enabled';

  /// Whether Android screenshot/screen-recording protection (`FLAG_SECURE`)
  /// is enabled. Defaults to `true` (secure by default) until toggled off.
  static Future<bool> isScreenSecurityEnabled() async {
    try {
      final value = await _storage.read(key: _screenSecurityKey);
      if (value == null) return true;
      return value != 'false';
    } catch (_) {
      return true;
    }
  }

  static Future<void> setScreenSecurityEnabled(bool enabled) async {
    try {
      await _storage.write(
        key: _screenSecurityKey,
        value: enabled ? 'true' : 'false',
      );
    } catch (_) {}
  }

  /// Whether sensitive clipboard protection (Android 13+ `EXTRA_IS_SENSITIVE`
  /// and 60s auto-clear for copied secret keys and decrypted plaintext) is
  /// enabled. Defaults to `true` until toggled off in Settings.
  static Future<bool> isSensitiveClipboardProtectionEnabled() async {
    try {
      final value = await _storage.read(key: _sensitiveClipboardProtectionKey);
      if (value == null) return true;
      return value != 'false';
    } catch (_) {
      return true;
    }
  }

  static Future<void> setSensitiveClipboardProtectionEnabled(
    bool enabled,
  ) async {
    try {
      await _storage.write(
        key: _sensitiveClipboardProtectionKey,
        value: enabled ? 'true' : 'false',
      );
    } catch (_) {}
  }

  static Future<bool> isDisclaimerAccepted() async {
    try {
      final value = await _storage.read(key: _disclaimerAcceptedKey);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  static Future<void> setDisclaimerAccepted(bool accepted) async {
    try {
      await _storage.write(
        key: _disclaimerAcceptedKey,
        value: accepted ? 'true' : 'false',
      );
    } catch (e) {}
  }

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
        final parsed = ObfuscationMethod.values.firstWhere(
          (e) => e.name == value && e != ObfuscationMethod.custom,
          orElse: () => ObfuscationService.defaultMethod,
        );
        final eq = parsed.v2Equivalent;
        return eq == ObfuscationMethod.custom
            ? ObfuscationService.defaultMethod
            : eq;
      }
    } catch (e) {}
    return ObfuscationService.defaultMethod;
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
    extends Notifier<AsyncValue<Map<String, dynamic>>> {
  @override
  AsyncValue<Map<String, dynamic>> build() {
    _loadSettings();
    return const AsyncValue.loading();
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

/// Manages Android `FLAG_SECURE` (screenshot & screen-recording protection) state.
class ScreenSecurityNotifier extends Notifier<bool> {
  bool _userUpdated = false;

  @override
  bool build() {
    _userUpdated = false;
    _load();
    return true;
  }

  Future<void> _load() async {
    final enabled = await SettingsStorageService.isScreenSecurityEnabled();
    if (!_userUpdated && ref.mounted) {
      state = enabled;
      await ScreenSecurityService.setSecureScreen(enabled);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _userUpdated = true;
    state = enabled;
    await SettingsStorageService.setScreenSecurityEnabled(enabled);
    await ScreenSecurityService.setSecureScreen(enabled);
  }
}

final screenSecurityProvider = NotifierProvider<ScreenSecurityNotifier, bool>(
  ScreenSecurityNotifier.new,
);

/// Manages sensitive clipboard protection state (default ON).
class SensitiveClipboardProtectionNotifier extends Notifier<bool> {
  bool _userUpdated = false;

  @override
  bool build() {
    _userUpdated = false;
    _load();
    return true;
  }

  Future<void> _load() async {
    final enabled =
        await SettingsStorageService.isSensitiveClipboardProtectionEnabled();
    if (!_userUpdated && ref.mounted) {
      state = enabled;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _userUpdated = true;
    state = enabled;
    await SettingsStorageService.setSensitiveClipboardProtectionEnabled(
      enabled,
    );
  }
}

final sensitiveClipboardProtectionProvider =
    NotifierProvider<SensitiveClipboardProtectionNotifier, bool>(
      SensitiveClipboardProtectionNotifier.new,
    );
