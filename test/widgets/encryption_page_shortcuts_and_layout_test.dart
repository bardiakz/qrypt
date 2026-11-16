import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/providers/resource_providers.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({
      'disclaimer_accepted_v1': 'true',
    });
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  group('EncryptionPage Desktop Shortcuts', () {
    testWidgets('provides CallbackShortcuts for Ctrl+M, Ctrl+Enter, Ctrl+L, Ctrl+Shift+C', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EncryptionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shortcutsFinder = find.byType(CallbackShortcuts);
      expect(shortcutsFinder, findsOneWidget);

      final callbackShortcuts = tester.widget<CallbackShortcuts>(shortcutsFinder);
      final bindings = callbackShortcuts.bindings;

      // Check shortcuts exist
      final hasCtrlM = bindings.keys.any((activator) =>
          activator is SingleActivator &&
          activator.trigger == LogicalKeyboardKey.keyM &&
          activator.control);
      final hasCtrlEnter = bindings.keys.any((activator) =>
          activator is SingleActivator &&
          activator.trigger == LogicalKeyboardKey.enter &&
          activator.control);
      final hasCtrlL = bindings.keys.any((activator) =>
          activator is SingleActivator &&
          activator.trigger == LogicalKeyboardKey.keyL &&
          activator.control);
      final hasCtrlShiftC = bindings.keys.any((activator) =>
          activator is SingleActivator &&
          activator.trigger == LogicalKeyboardKey.keyC &&
          activator.control &&
          activator.shift);

      expect(hasCtrlM, isTrue);
      expect(hasCtrlEnter, isTrue);
      expect(hasCtrlL, isTrue);
      expect(hasCtrlShiftC, isTrue);
    });

    testWidgets('Ctrl+M shortcut toggles between encrypt and decrypt modes', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EncryptionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(appModeProvider), AppMode.encrypt);

      // Send Ctrl+M
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(container.read(appModeProvider), AppMode.decrypt);

      // Send Ctrl+M again to toggle back
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(container.read(appModeProvider), AppMode.encrypt);
    });
  });
}
