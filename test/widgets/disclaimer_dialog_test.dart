import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/pages/settings_page.dart';
import 'package:qrypt/pages/widgets/disclaimer_dialog.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/settings/settings_storage_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  group('DisclaimerDialog Widget Tests', () {
    testWidgets('renders all critical legal sections and backward compatibility warning', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DisclaimerDialog(isFirstTime: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Important Notice & Disclaimer'), findsOneWidget);
      expect(find.textContaining('Legitimate & Educational Purpose'), findsOneWidget);
      expect(find.textContaining('No Warranty'), findsOneWidget);
      expect(find.textContaining('No Guaranteed Backward Compatibility'), findsOneWidget);
      expect(find.textContaining('backward compatibility is NOT guaranteed'), findsOneWidget);
      expect(find.textContaining('Limitation of Liability'), findsOneWidget);
      expect(find.text('I Understand & Accept'), findsOneWidget);
    });

    testWidgets('first-time acceptance updates SettingsStorageService and invokes callback', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await SettingsStorageService.isDisclaimerAccepted(), isFalse);

      bool callbackInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DisclaimerDialog.show(
                  context,
                  isFirstTime: true,
                  onAccepted: () {
                    callbackInvoked = true;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap open
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(DisclaimerDialog), findsOneWidget);

      // Tap I Understand & Accept
      await tester.tap(find.text('I Understand & Accept'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(DisclaimerDialog), findsNothing);
      expect(callbackInvoked, isTrue);
      expect(await SettingsStorageService.isDisclaimerAccepted(), isTrue);
    });

    testWidgets('non-first-time dialog shows Close button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DisclaimerDialog(isFirstTime: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Close'), findsOneWidget);
      expect(find.text('I Understand & Accept'), findsNothing);
    });

    testWidgets('EncryptionPage automatically displays DisclaimerDialog on first launch', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await SettingsStorageService.isDisclaimerAccepted(), isFalse);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EncryptionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // DisclaimerDialog should automatically appear
      expect(find.byType(DisclaimerDialog), findsOneWidget);

      // Accept
      await tester.tap(find.text('I Understand & Accept'));
      await tester.pumpAndSettle();

      expect(find.byType(DisclaimerDialog), findsNothing);
      expect(await SettingsStorageService.isDisclaimerAccepted(), isTrue);
    });

    testWidgets('EncryptionPage does NOT show DisclaimerDialog if already accepted', (
      WidgetTester tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({
        'disclaimer_accepted_v1': 'true',
      });
      expect(await SettingsStorageService.isDisclaimerAccepted(), isTrue);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EncryptionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DisclaimerDialog), findsNothing);
    });

    testWidgets('SettingsPage renders Privacy Policy and opens updated dialog', (
      WidgetTester tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'Qrypt',
        packageName: 'com.example.qrypt',
        version: '5.4.1',
        buildNumber: '21',
        buildSignature: '',
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final privacyTile = find.widgetWithText(ListTile, 'Privacy Policy');
      expect(privacyTile, findsOneWidget);

      await tester.tap(privacyTile);
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.textContaining('100% Offline & Private'), findsOneWidget);
      expect(find.textContaining('Local Secure Storage'), findsOneWidget);
      expect(find.textContaining('No Warranty & Compatibility'), findsOneWidget);
      expect(find.text('View Online'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('100% Offline & Private'), findsNothing);
    });
  });
}
