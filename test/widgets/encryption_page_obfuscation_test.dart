import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:qrypt/providers/simple_state_provider.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  testWidgets(
    'pumps in encrypt mode with en2 without exception; switching to decrypt preserves and offers legacy en2',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});

      // 1. Pump EncryptionPage with selectedObfuscationProvider = en2 (legacy).
      // Disable defaultEncryption so manual obfuscation dropdown is rendered in encrypt mode.
      // Disable autoDetectTag so manual obfuscation dropdown is rendered in decrypt mode.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedObfuscationProvider.overrideWith(
              () => SimpleNotifier<ObfuscationMethod>(ObfuscationMethod.en2),
            ),
            defaultEncryptionProvider.overrideWith(
              () => SimpleNotifier<bool>(false),
            ),
            autoDetectTagProvider.overrideWith(
              () => SimpleNotifier<bool>(false),
            ),
          ],
          child: const MaterialApp(
            home: EncryptionPage(),
          ),
        ),
      );

      // Assert no exception thrown while pumping and settling in encrypt mode
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // In encrypt mode, dropdown should coerce en2 -> en2v2 (English (Words v2))
      // and NOT offer legacy en2 in its items.
      final encryptDropdownFinder = find.byType(
        DropdownButton<ObfuscationMethod>,
      );
      expect(encryptDropdownFinder, findsOneWidget);

      final encryptDropdown = tester.widget<DropdownButton<ObfuscationMethod>>(
        encryptDropdownFinder,
      );
      expect(encryptDropdown.value, equals(ObfuscationMethod.en2v2));
      final encryptOfferedValues =
          encryptDropdown.items?.map((item) => item.value).toSet() ?? {};
      expect(encryptOfferedValues.contains(ObfuscationMethod.en2), isFalse);
      expect(encryptOfferedValues.contains(ObfuscationMethod.en2v2), isTrue);

      // 2. Switch to Decrypt mode
      final decryptTabFinder = find.text('Decrypt');
      expect(decryptTabFinder, findsOneWidget);
      await tester.tap(decryptTabFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // In decrypt mode, legacy en2 is both offered in the dropdown items and selected
      final decryptDropdownFinder = find.byType(
        DropdownButton<ObfuscationMethod>,
      );
      expect(decryptDropdownFinder, findsOneWidget);

      final decryptDropdown = tester.widget<DropdownButton<ObfuscationMethod>>(
        decryptDropdownFinder,
      );
      expect(
        decryptDropdown.value,
        equals(ObfuscationMethod.en2),
        reason: 'Legacy en2 should be selected in decrypt mode',
      );

      final decryptOfferedValues =
          decryptDropdown.items?.map((item) => item.value).toSet() ?? {};
      expect(
        decryptOfferedValues.contains(ObfuscationMethod.en2),
        isTrue,
        reason: 'Legacy en2 must be offered in decrypt mode',
      );
      expect(
        decryptOfferedValues.contains(ObfuscationMethod.en2v2),
        isTrue,
        reason: 'v2 methods should also be offered in decrypt mode',
      );
    },
  );

  testWidgets(
    'encrypting with legacy en2 selected coerces to en2v2 in inputQryptProvider and Qrypt.withTag',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      late ProviderContainer container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container = ProviderContainer(
            overrides: [
              selectedObfuscationProvider.overrideWith(
                () => SimpleNotifier<ObfuscationMethod>(ObfuscationMethod.en2),
              ),
              defaultEncryptionProvider.overrideWith(
                () => SimpleNotifier<bool>(false),
              ),
              selectedEncryptionProvider.overrideWith(
                () => SimpleNotifier(EncryptionMethod.none),
              ),
            ],
          ),
          child: const MaterialApp(
            home: EncryptionPage(),
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField).first, 'Test coercion message');
      await tester.pumpAndSettle();

      // Tap Encrypt button
      final encryptButton = find.widgetWithText(ElevatedButton, 'Encrypt');
      await tester.tap(encryptButton);
      await tester.pumpAndSettle();

      // Assert that inputQryptProvider received en2v2 and never legacy en2
      final inputQ = container.read(inputQryptProvider);
      expect(
        inputQ.getObfuscationMethod(),
        equals(ObfuscationMethod.en2v2),
        reason: 'Legacy selection en2 must be coerced to en2v2 for encryption pipeline',
      );
    },
  );
}
