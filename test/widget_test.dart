import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrypt/main.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  testWidgets('App launches and renders EncryptionPage smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
  });

  testWidgets(
    'tapping Encrypt without key prompts CreateAESKeyDialog and cancel leaves isProcessing false',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(const ProviderScope(child: MyApp()));
      await tester.pumpAndSettle();

      // Enter text into the first textfield
      await tester.enterText(
        find.byType(TextField).first,
        'Test Secret Message',
      );
      await tester.pumpAndSettle();

      // Tap Encrypt button
      final encryptButton = find.widgetWithText(ElevatedButton, 'Encrypt');
      await tester.tap(encryptButton);
      await tester.pumpAndSettle();

      // Key creation dialog should be presented
      expect(find.text('Save AES Key'), findsOneWidget);

      // Tap Cancel on the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify dialog is gone
      expect(find.text('Save AES Key'), findsNothing);

      // Verify not stuck in processing state
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Encryption cancelled: AES key required.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('rapid double-tap on Encrypt only prompts for key once', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // Enter text
    await tester.enterText(find.byType(TextField).first, 'Double tap test');
    await tester.pumpAndSettle();

    // Fire onPressed twice concurrently while key retrieval is in-flight
    final encryptButton = find.widgetWithText(ElevatedButton, 'Encrypt');
    final button = tester.widget<ElevatedButton>(encryptButton);
    button.onPressed?.call();
    button.onPressed?.call();
    await tester.pumpAndSettle();

    // Verify exactly one dialog is open
    expect(find.text('Save AES Key'), findsOneWidget);

    // Cancel and clean up
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
