import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oqs/oqs.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/pages/settings_page.dart';
import 'package:qrypt/pages/widgets/aes/create_aes_key_dialog.dart';
import 'package:qrypt/pages/widgets/ml_dsa/create_ml_dsa_key_dialog.dart';
import 'package:qrypt/pages/widgets/ml_dsa/ml_dsa_key_management_dialog.dart';
import 'package:qrypt/pages/widgets/ml_kem/create_kem_key_dialog.dart';
import 'package:qrypt/pages/widgets/ml_kem/kem_key_management_dialog.dart';
import 'package:qrypt/pages/widgets/rsa/create_rsa_key_dialog.dart';
import 'package:qrypt/pages/widgets/rsa/rsa_key_management_dialog.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/providers/ml_dsa_providers.dart';
import 'package:qrypt/providers/rsa_providers.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/screen_security_service.dart';
import 'package:qrypt/services/secure_storage_config.dart';
import 'package:qrypt/services/settings/settings_storage_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const screenSecurityChannel = MethodChannel(
    'io.github.bardiakz.qrypt/screen_security',
  );

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
    FlutterSecureStorage.setMockInitialValues({
      'disclaimer_accepted_v1': 'true',
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screenSecurityChannel, null);
  });

  group('[M-08b] Hardened FlutterSecureStorage configuration', () {
    test('pins Android resetOnError: false and Apple unlocked_this_device', () {
      expect(qryptSecureStorage.aOptions.params['resetOnError'], 'false');
      expect(
        qryptSecureStorage.iOptions.accessibility,
        KeychainAccessibility.unlocked_this_device,
      );
      expect(qryptSecureStorage.iOptions.synchronizable, isFalse);
      expect(
        qryptSecureStorage.mOptions.accessibility,
        KeychainAccessibility.unlocked_this_device,
      );
      expect(qryptSecureStorage.mOptions.synchronizable, isFalse);
    });
  });

  group('[M-07] Android FLAG_SECURE service, storage, and Settings toggle', () {
    test('defaults to enabled and persists toggled state', () async {
      expect(await SettingsStorageService.isScreenSecurityEnabled(), isTrue);

      await SettingsStorageService.setScreenSecurityEnabled(false);
      expect(await SettingsStorageService.isScreenSecurityEnabled(), isFalse);

      await SettingsStorageService.setScreenSecurityEnabled(true);
      expect(await SettingsStorageService.isScreenSecurityEnabled(), isTrue);
    });

    test('invokes MethodChannel only on Android', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(screenSecurityChannel, (call) async {
            calls.add(call);
            return true;
          });

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(ScreenSecurityService.isSupported, isFalse);
      expect(await ScreenSecurityService.setSecureScreen(true), isFalse);
      expect(calls, isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(ScreenSecurityService.isSupported, isTrue);
      expect(await ScreenSecurityService.setSecureScreen(true), isTrue);
      expect(await ScreenSecurityService.setSecureScreen(false), isTrue);

      expect(calls.length, 2);
      expect(calls[0].method, 'setFlagSecure');
      expect(calls[0].arguments, {'enabled': true});
      expect(calls[1].method, 'setFlagSecure');
      expect(calls[1].arguments, {'enabled': false});
    });

    testWidgets('SettingsPage shows and toggles FLAG_SECURE on Android', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(screenSecurityChannel, (call) async {
            calls.add(call);
            return true;
          });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Security'), findsOneWidget);
      final toggleFinder = find.widgetWithText(
        SwitchListTile,
        'Block Screenshots & Screen Recording',
      );
      expect(toggleFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isTrue);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);
      expect(await SettingsStorageService.isScreenSecurityEnabled(), isFalse);
      expect(calls.last.method, 'setFlagSecure');
      expect(calls.last.arguments, {'enabled': false});

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('SettingsPage hides Android FLAG_SECURE section on Linux', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Block Screenshots & Screen Recording'), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('[L-02] EncryptionMethod.none warnings', () {
    testWidgets(
      'warns on obfuscation-only mode and preserves Base64 fallback warning',
      (WidgetTester tester) async {
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

        // Switch to manual mode with EncryptionMethod.none + ObfuscationMethod.en2v2
        container.read(defaultEncryptionProvider.notifier).state = false;
        container.read(selectedEncryptionProvider.notifier).state =
            EncryptionMethod.none;
        container.read(selectedObfuscationProvider.notifier).state =
            ObfuscationMethod.en2v2;
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Warning: Encryption is disabled. Obfuscation only disguises format and does not provide cryptographic confidentiality.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Warning: No encryption or obfuscation is selected. Output will be Base64-encoded by default.',
          ),
          findsNothing,
        );

        // Switch obfuscation to none -> preserves Base64 fallback warning
        container.read(selectedObfuscationProvider.notifier).state =
            ObfuscationMethod.none;
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Warning: No encryption or obfuscation is selected. Output will be Base64-encoded by default.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Warning: Encryption is disabled. Obfuscation only disguises format and does not provide cryptographic confidentiality.',
          ),
          findsNothing,
        );

        // Switch encryption back to AES-GCM -> both warnings hidden
        container.read(selectedEncryptionProvider.notifier).state =
            EncryptionMethod.aesGcm;
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Warning: Encryption is disabled'),
          findsNothing,
        );
        expect(
          find.textContaining('Warning: No encryption or obfuscation'),
          findsNothing,
        );
      },
    );
  });

  group('[L-03] Secret key reveal toggles & obscured manual inputs', () {
    testWidgets('RSA export hides private key until Reveal is tapped', (
      WidgetTester tester,
    ) async {
      const secretPem =
          '-----BEGIN RSA PRIVATE KEY-----\nSECRET_RSA_TEST_PAYLOAD\n-----END RSA PRIVATE KEY-----';
      final sampleRsa = RSAKeyPair(
        id: 'rsa-l03',
        name: 'TestRSA',
        publicKey:
            '-----BEGIN PUBLIC KEY-----\nPUBLIC_RSA_TEST_PAYLOAD\n-----END PUBLIC KEY-----',
        privateKey: secretPem,
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rsaKeyPairsProvider.overrideWith((ref) => Future.value([sampleRsa])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RSAKeyManagementDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      // Public key visible, private key hidden by default
      expect(find.textContaining('PUBLIC_RSA_TEST_PAYLOAD'), findsOneWidget);
      expect(find.textContaining('SECRET_RSA_TEST_PAYLOAD'), findsNothing);
      expect(find.text('Reveal Private Key'), findsOneWidget);

      // Reveal private key
      await tester.tap(find.text('Reveal Private Key'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET_RSA_TEST_PAYLOAD'), findsOneWidget);
      expect(find.text('Hide Private Key'), findsOneWidget);

      // Hide again
      await tester.tap(find.text('Hide Private Key'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET_RSA_TEST_PAYLOAD'), findsNothing);
    });

    testWidgets('ML-KEM export hides secret key until Reveal is tapped', (
      WidgetTester tester,
    ) async {
      final pubBytes = Uint8List.fromList([10, 20, 30, 40]);
      final secBytes = Uint8List.fromList([99, 88, 77, 66]);
      final sampleKem = QryptKEMKeyPair(
        id: 'kem-l03',
        name: 'TestKEM',
        algorithm: 'ML-KEM-768',
        createdAt: DateTime(2026, 1, 1),
        kemKeyPair: KEMKeyPair(publicKey: pubBytes, secretKey: secBytes),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kemKeyPairsProvider.overrideWith((ref) => Future.value([sampleKem])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: KemKeyManagementDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text(base64Encode(pubBytes)), findsOneWidget);
      expect(find.text(base64Encode(secBytes)), findsNothing);

      await tester.tap(find.text('Reveal Secret Key'));
      await tester.pumpAndSettle();
      expect(find.text(base64Encode(secBytes)), findsOneWidget);
    });

    testWidgets('ML-DSA export hides secret key until Reveal is tapped', (
      WidgetTester tester,
    ) async {
      final pubBytes = Uint8List.fromList([11, 22, 33, 44]);
      final secBytes = Uint8List.fromList([55, 66, 77, 88]);
      final sampleDsa = QryptMLDSAKeyPair.fromComponents(
        id: 'dsa-l03',
        name: 'TestDSA',
        algorithm: 'ML-DSA-65',
        publicKey: pubBytes,
        secretKey: secBytes,
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mlDsaKeyPairsProvider.overrideWith(
              (ref) => Future.value([sampleDsa]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MlDsaKeyManagementDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text(base64Encode(pubBytes)), findsOneWidget);
      expect(find.text(base64Encode(secBytes)), findsNothing);

      await tester.tap(find.text('Reveal Secret Key'));
      await tester.pumpAndSettle();
      expect(find.text(base64Encode(secBytes)), findsOneWidget);
    });

    testWidgets(
      'CreateAESKeyDialog obscures manual secret key by default with toggle',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: CreateAESKeyDialog(primaryColor: Colors.blue)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        final secretFieldFinder = find.widgetWithText(
          TextField,
          'AES Secret Key',
        );
        expect(tester.widget<TextField>(secretFieldFinder).obscureText, isTrue);

        await tester.tap(find.byTooltip('Show secret key'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(secretFieldFinder).obscureText, isFalse);
      },
    );

    testWidgets(
      'CreateRSAKeyDialog obscures manual private key by default with dynamic maxLines',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: CreateRSAKeyDialog(primaryColor: Colors.blue)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        final privateFieldFinder = find.widgetWithText(TextField, 'Private Key');
        final obscuredField = tester.widget<TextField>(privateFieldFinder);
        expect(obscuredField.obscureText, isTrue);
        expect(obscuredField.maxLines, 1);

        await tester.tap(find.byTooltip('Show private key'));
        await tester.pumpAndSettle();

        final visibleField = tester.widget<TextField>(privateFieldFinder);
        expect(visibleField.obscureText, isFalse);
        expect(visibleField.maxLines, 4);
      },
    );

    testWidgets(
      'CreateKemKeyDialog obscures manual secret key by default with dynamic maxLines',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: CreateKemKeyDialog(primaryColor: Colors.blue)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        final secretFieldFinder = find.widgetWithText(TextField, 'Secret Key');
        expect(tester.widget<TextField>(secretFieldFinder).obscureText, isTrue);
        expect(tester.widget<TextField>(secretFieldFinder).maxLines, 1);

        await tester.tap(find.byTooltip('Show secret key'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(secretFieldFinder).obscureText, isFalse);
        expect(tester.widget<TextField>(secretFieldFinder).maxLines, 4);
      },
    );

    testWidgets(
      'CreateMlDsaKeyDialog obscures manual secret key by default with dynamic maxLines',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: CreateMlDsaKeyDialog(primaryColor: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        final secretFieldFinder = find.widgetWithText(TextField, 'Secret Key');
        expect(tester.widget<TextField>(secretFieldFinder).obscureText, isTrue);
        expect(tester.widget<TextField>(secretFieldFinder).maxLines, 1);

        await tester.tap(find.byTooltip('Show secret key'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(secretFieldFinder).obscureText, isFalse);
        expect(tester.widget<TextField>(secretFieldFinder).maxLines, 4);
      },
    );
  });
}
