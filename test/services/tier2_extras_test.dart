import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/pages/settings_page.dart';
import 'package:qrypt/pages/widgets/web_storage_notice_banner.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:qrypt/providers/resource_providers.dart';
import 'package:qrypt/services/clipboard_security_service.dart';
import 'package:qrypt/services/compression_web.dart' as web_compression;
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/settings/settings_storage_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clipboardSecurityChannel = MethodChannel(
    'io.github.bardiakz.qrypt/clipboard_security',
  );

  String? mockClipboardText;
  final List<MethodCall> nativeClipboardCalls = [];
  final List<MethodCall> platformClipboardCalls = [];

  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Qrypt',
      packageName: 'com.bardiakz.qrypt',
      version: '5.7.2',
      buildNumber: '26',
      buildSignature: '',
    );
    FlutterSecureStorage.setMockInitialValues({
      'disclaimer_accepted_v1': 'true',
    });
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  setUp(() {
    mockClipboardText = null;
    nativeClipboardCalls.clear();
    platformClipboardCalls.clear();
    ClipboardSecurityService.cancelPendingClear();
    FlutterSecureStorage.setMockInitialValues({
      'disclaimer_accepted_v1': 'true',
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardSecurityChannel, (call) async {
          nativeClipboardCalls.add(call);
          if (call.method == 'setSensitiveText') {
            final args = call.arguments as Map<dynamic, dynamic>;
            mockClipboardText = args['text'] as String?;
            return true;
          }
          if (call.method == 'clearClipboard') {
            mockClipboardText = '';
            return true;
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            platformClipboardCalls.add(call);
            final args = call.arguments as Map<dynamic, dynamic>;
            mockClipboardText = args['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': mockClipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    ClipboardSecurityService.cancelPendingClear();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardSecurityChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('[L-03] Sensitive Clipboard Protection', () {
    test('SettingsStorageService defaults to true and persists toggle', () async {
      expect(
        await SettingsStorageService.isSensitiveClipboardProtectionEnabled(),
        isTrue,
      );

      await SettingsStorageService.setSensitiveClipboardProtectionEnabled(
        false,
      );
      expect(
        await SettingsStorageService.isSensitiveClipboardProtectionEnabled(),
        isFalse,
      );

      await SettingsStorageService.setSensitiveClipboardProtectionEnabled(true);
      expect(
        await SettingsStorageService.isSensitiveClipboardProtectionEnabled(),
        isTrue,
      );
    });

    test(
      'non-sensitive copy (ciphertext/public key) skips Android flag and auto-clear timer',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final result = await ClipboardSecurityService.copyText(
          'CIPHERTEXT_OR_PUBLIC_KEY',
          isSensitive: false,
          autoClearDuration: const Duration(milliseconds: 20),
        );

        expect(result.markedSensitive, isFalse);
        expect(result.autoClearScheduled, isFalse);
        expect(ClipboardSecurityService.hasPendingAutoClear, isFalse);
        expect(nativeClipboardCalls, isEmpty);
        expect(platformClipboardCalls.length, 1);
        expect(mockClipboardText, 'CIPHERTEXT_OR_PUBLIC_KEY');
      },
    );

    test(
      'sensitive copy on Android marks EXTRA_IS_SENSITIVE and auto-clears if unchanged',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final result = await ClipboardSecurityService.copyText(
          'SUPER_SECRET_KEY',
          isSensitive: true,
          autoClearDuration: const Duration(milliseconds: 40),
        );

        expect(result.markedSensitive, isTrue);
        expect(result.autoClearScheduled, isTrue);
        expect(ClipboardSecurityService.hasPendingAutoClear, isTrue);
        expect(nativeClipboardCalls.length, 1);
        expect(nativeClipboardCalls.first.method, 'setSensitiveText');
        expect(mockClipboardText, 'SUPER_SECRET_KEY');

        await Future<void>.delayed(const Duration(milliseconds: 90));

        expect(ClipboardSecurityService.hasPendingAutoClear, isFalse);
        expect(nativeClipboardCalls.length, 2);
        expect(nativeClipboardCalls.last.method, 'clearClipboard');
        expect(mockClipboardText, '');
      },
    );

    test(
      'sensitive auto-clear does NOT wipe clipboard if user copied something else',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await ClipboardSecurityService.copyText(
          'DECRYPTED_SECRET_1',
          isSensitive: true,
          autoClearDuration: const Duration(milliseconds: 40),
        );
        expect(mockClipboardText, 'DECRYPTED_SECRET_1');

        // Simulate user copying an unrelated text in another app before timer fires
        mockClipboardText = 'UNRELATED_USER_CLIPBOARD_DATA';

        await Future<void>.delayed(const Duration(milliseconds: 90));

        expect(nativeClipboardCalls.length, 1); // Only setSensitiveText, no clearClipboard
        expect(mockClipboardText, 'UNRELATED_USER_CLIPBOARD_DATA');
      },
    );

    test(
      'sensitive copy when Settings toggle is OFF bypasses native flag and auto-clear',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await SettingsStorageService.setSensitiveClipboardProtectionEnabled(
          false,
        );

        final result = await ClipboardSecurityService.copyText(
          'AES_SECRET_KEY_OPT_OUT',
          isSensitive: true,
          autoClearDuration: const Duration(milliseconds: 20),
        );

        expect(result.markedSensitive, isFalse);
        expect(result.autoClearScheduled, isFalse);
        expect(ClipboardSecurityService.hasPendingAutoClear, isFalse);
        expect(nativeClipboardCalls, isEmpty);
        expect(platformClipboardCalls.length, 1);
        expect(mockClipboardText, 'AES_SECRET_KEY_OPT_OUT');

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(mockClipboardText, 'AES_SECRET_KEY_OPT_OUT');
      },
    );

    test(
      'subsequent non-sensitive copy cancels pending sensitive auto-clear timer',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;

        await ClipboardSecurityService.copyText(
          'SECRET_PLAINTEXT',
          isSensitive: true,
          autoClearDuration: const Duration(milliseconds: 50),
        );
        expect(ClipboardSecurityService.hasPendingAutoClear, isTrue);

        await ClipboardSecurityService.copyText(
          'PUBLIC_CIPHERTEXT',
          isSensitive: false,
        );
        expect(ClipboardSecurityService.hasPendingAutoClear, isFalse);
        expect(mockClipboardText, 'PUBLIC_CIPHERTEXT');

        await Future<void>.delayed(const Duration(milliseconds: 90));
        expect(mockClipboardText, 'PUBLIC_CIPHERTEXT');
      },
    );

    testWidgets(
      'SettingsPage shows Protect Sensitive Clipboard toggle (default ON) and persists OFF',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SettingsPage())),
        );
        await tester.pumpAndSettle();

        expect(find.text('Security'), findsOneWidget);
        final toggleFinder = find.widgetWithText(
          SwitchListTile,
          'Protect Sensitive Clipboard',
        );
        expect(toggleFinder, findsOneWidget);
        expect(tester.widget<SwitchListTile>(toggleFinder).value, isTrue);

        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);
        expect(
          await SettingsStorageService.isSensitiveClipboardProtectionEnabled(),
          isFalse,
        );

        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'EncryptionPage protects decrypted plaintext copy but not encrypted ciphertext copy',
      (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: EncryptionPage())),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(EncryptionPage)),
        );

        // 1. Encrypt mode: copying ciphertext must NOT mark sensitive or schedule auto-clear
        container.read(appModeProvider.notifier).state = AppMode.encrypt;
        container.read(processedEncryptProvider).text = 'ENCRYPTED_CIPHERTEXT';
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Copy output (Ctrl+Shift+C)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(nativeClipboardCalls, isEmpty);
        expect(ClipboardSecurityService.hasPendingAutoClear, isFalse);
        expect(mockClipboardText, 'ENCRYPTED_CIPHERTEXT');
        expect(find.text('Copied to clipboard!'), findsOneWidget);

        // 2. Decrypt mode: copying decrypted plaintext MUST mark sensitive & schedule auto-clear
        container.read(appModeProvider.notifier).state = AppMode.decrypt;
        container.read(processedDecryptProvider).text = 'DECRYPTED_SECRET_MSG';
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Copy output (Ctrl+Shift+C)'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(nativeClipboardCalls.length, 1);
        expect(nativeClipboardCalls.first.method, 'setSensitiveText');
        expect(ClipboardSecurityService.hasPendingAutoClear, isTrue);
        expect(mockClipboardText, 'DECRYPTED_SECRET_MSG');
        expect(
          find.text('Copied to clipboard (auto-clears in 60s)'),
          findsOneWidget,
        );

        // Cancel pending 60s timer before widget tree disposal
        ClipboardSecurityService.cancelPendingClear();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  });

  group('[M-06] Bounded streaming GZip decompression on Flutter Web', () {
    test('roundtrips valid UTF-8 and binary payloads within limit', () {
      final original = utf8.encode('Hello Qrypt Web bounded streaming GZip!');
      final compressed = web_compression.Compression.gZipCompress(original);
      final decompressed = web_compression.Compression.gZipDeCompress(
        compressed,
        maxBytes: original.length,
      );

      expect(decompressed, equals(original));
      expect(web_compression.Compression.gZipDeCompress(const []), isEmpty);
    });

    test('aborts GZip decompression bomb with DecompressionBombException', () {
      // 1 MB of zeros compresses to ~1 KB in GZip
      final bombInput = Uint8List(1024 * 1024);
      final compressedBomb = web_compression.Compression.gZipCompress(
        bombInput,
      );
      expect(compressedBomb.length, lessThan(4096));

      expect(
        () => web_compression.Compression.gZipDeCompress(
          compressedBomb,
          maxBytes: 1024,
        ),
        throwsA(isA<web_compression.DecompressionBombException>()),
      );
    });

    test('enforces exact maxBytes boundary and rejects malformed GZip data', () {
      final payload = Uint8List.fromList(List<int>.generate(256, (i) => i));
      final compressed = web_compression.Compression.gZipCompress(payload);

      // Exact limit succeeds
      expect(
        web_compression.Compression.gZipDeCompress(compressed, maxBytes: 256),
        equals(payload),
      );
      // 1 byte below limit aborts
      expect(
        () => web_compression.Compression.gZipDeCompress(
          compressed,
          maxBytes: 255,
        ),
        throwsA(isA<web_compression.DecompressionBombException>()),
      );

      // Malformed GZip payload throws error rather than returning partial/empty bytes
      expect(
        () => web_compression.Compression.gZipDeCompress(
          const [0x00, 0x01, 0x02, 0x03, 0x04],
        ),
        throwsA(anything),
      );
    });
  });

  group('[M-08] Web Storage Notice Banner', () {
    testWidgets('is hidden when showOnCurrentPlatform is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WebStorageNoticeBanner(showOnCurrentPlatform: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('hardware-backed Keystore/Keychain'),
        findsNothing,
      );
    });

    testWidgets('is visible when showOnCurrentPlatform is true and dismisses', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WebStorageNoticeBanner(showOnCurrentPlatform: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('hardware-backed Keystore/Keychain'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Dismiss web storage notice'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('hardware-backed Keystore/Keychain'),
        findsNothing,
      );
    });
  });
}
