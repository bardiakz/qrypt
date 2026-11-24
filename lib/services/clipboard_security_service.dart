import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qrypt/services/settings/settings_storage_service.dart';

/// Result metadata returned after writing text to the system clipboard.
class ClipboardCopyResult {
  final bool markedSensitive;
  final bool autoClearScheduled;
  final Duration? clearAfter;

  const ClipboardCopyResult({
    required this.markedSensitive,
    required this.autoClearScheduled,
    this.clearAfter,
  });
}

/// Manages clipboard writes with opt-out sensitive data protection.
///
/// Strictly intended for **secret keys** and **decrypted plaintext** when
/// `isSensitive == true`. Non-sensitive payloads (ciphertexts, public keys,
/// obfuscation maps) bypass sensitive flags and auto-clear timers completely.
class ClipboardSecurityService {
  static const MethodChannel _channel = MethodChannel(
    'io.github.bardiakz.qrypt/clipboard_security',
  );

  static const Duration defaultAutoClearDuration = Duration(seconds: 60);

  static Timer? _clearTimer;
  static String? _pendingSensitiveText;

  /// Whether Android 13+ `ClipDescription.EXTRA_IS_SENSITIVE` channel support
  /// is available on the current platform.
  static bool get supportsAndroidSensitiveFlag =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether a sensitive clipboard auto-clear timer is currently scheduled.
  static bool get hasPendingAutoClear =>
      _clearTimer != null && _clearTimer!.isActive;

  /// Cancels any scheduled sensitive clipboard clear timer.
  static void cancelPendingClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _pendingSensitiveText = null;
  }

  /// Copies [text] to the clipboard.
  ///
  /// When [isSensitive] is `true` and the user has **Protect Sensitive Clipboard**
  /// enabled in Settings (enabled by default):
  /// - Marks the clipboard entry as sensitive (`EXTRA_IS_SENSITIVE`) on Android.
  /// - Schedules an auto-clear timer (60 seconds by default) that clears the
  ///   clipboard **only** if it still contains the exact copied secret.
  ///
  /// When [isSensitive] is `false` (ciphertexts, public keys, obfuscation maps),
  /// or when the Settings toggle is disabled, writes directly via standard
  /// `Clipboard.setData` with no auto-clear timer.
  static Future<ClipboardCopyResult> copyText(
    String text, {
    required bool isSensitive,
    Duration? autoClearDuration,
  }) async {
    // Always cancel any prior timer so copying new content never causes an
    // older secret's timer to interfere.
    cancelPendingClear();

    final protectionEnabled = isSensitive
        ? await SettingsStorageService.isSensitiveClipboardProtectionEnabled()
        : false;

    if (!isSensitive || !protectionEnabled) {
      await Clipboard.setData(ClipboardData(text: text));
      return const ClipboardCopyResult(
        markedSensitive: false,
        autoClearScheduled: false,
      );
    }

    bool markedSensitive = false;
    if (supportsAndroidSensitiveFlag) {
      try {
        final nativeResult = await _channel.invokeMethod<bool>(
          'setSensitiveText',
          {'text': text, 'label': 'Qrypt Secret'},
        );
        markedSensitive = nativeResult ?? false;
      } on MissingPluginException {
        markedSensitive = false;
      } on PlatformException catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to set Android sensitive clipboard flag: $e');
        }
        markedSensitive = false;
      }
    }

    if (!markedSensitive) {
      await Clipboard.setData(ClipboardData(text: text));
    }

    final clearDuration = autoClearDuration ?? defaultAutoClearDuration;
    _pendingSensitiveText = text;
    _clearTimer = Timer(clearDuration, () {
      unawaited(_clearIfUnchanged(text));
    });

    return ClipboardCopyResult(
      markedSensitive: markedSensitive,
      autoClearScheduled: true,
      clearAfter: clearDuration,
    );
  }

  static Future<void> _clearIfUnchanged(String expectedSecret) async {
    if (_pendingSensitiveText != expectedSecret) {
      return;
    }
    _clearTimer = null;
    _pendingSensitiveText = null;

    try {
      final current = await Clipboard.getData('text/plain');
      if (current?.text != expectedSecret) {
        // User already copied something else; do not touch their clipboard.
        return;
      }

      bool clearedNatively = false;
      if (supportsAndroidSensitiveFlag) {
        try {
          final result = await _channel.invokeMethod<bool>('clearClipboard');
          clearedNatively = result ?? false;
        } on MissingPluginException {
          clearedNatively = false;
        } on PlatformException {
          clearedNatively = false;
        }
      }

      if (!clearedNatively) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to auto-clear sensitive clipboard: $e');
      }
    }
  }
}
