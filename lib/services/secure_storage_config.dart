import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized secure storage configuration for Qrypt (`flutter_secure_storage` v11.2.0+).
///
/// - Android: uses RSA-OAEP-SHA256 + AES-GCM by default, with `resetOnError: false`
///   so transient KeyStore errors never silently wipe stored keys.
/// - iOS / macOS: pins `unlocked_this_device` (hardware-bound, excluded from device
///   backups and iCloud Keychain sync). `flutter_secure_storage_darwin` 0.4.3+
///   automatically finds existing Keychain items written under prior accessibility levels.
const FlutterSecureStorage qryptSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  ),
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  ),
);
