import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls Android `WindowManager.LayoutParams.FLAG_SECURE` via a dedicated
/// platform MethodChannel so screenshots, screen recordings, and recents-screen
/// previews can be toggled by the user in Settings.
class ScreenSecurityService {
  static const MethodChannel _channel = MethodChannel(
    'io.github.bardiakz.qrypt/screen_security',
  );

  /// Whether OS-level screen capture protection (`FLAG_SECURE`) is supported on
  /// the current platform.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Enables or disables Android `FLAG_SECURE`.
  ///
  /// Returns `true` if the platform acknowledged the update, or `false` on
  /// unsupported platforms / unit-test hosts where the native channel is absent.
  static Future<bool> setSecureScreen(bool enabled) async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('setFlagSecure', {
        'enabled': enabled,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update FLAG_SECURE: $e');
      }
      return false;
    }
  }
}
