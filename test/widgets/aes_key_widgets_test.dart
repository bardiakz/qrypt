import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/pages/widgets/aes/aes_key_management_dialog.dart';
import 'package:qrypt/pages/widgets/aes/aes_key_selector.dart';
import 'package:qrypt/pages/widgets/aes/create_aes_key_dialog.dart';
import 'package:qrypt/services/aes/aes_key_storage_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AESKeySelector Widget', () {
    testWidgets('shows empty state when no keys are saved', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AESEncryptKeySelector(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AES Key (Encrypt)'), findsOneWidget);
      expect(find.text('No saved AES keys available'), findsOneWidget);
      expect(find.text('Create AES Key'), findsOneWidget);
    });

    testWidgets('shows dropdown with keys when keys exist', (
      WidgetTester tester,
    ) async {
      const storageService = AesKeyStorageService();
      await storageService.saveKey(
        AESKey(
          id: 'test-1',
          name: 'Primary Key',
          key: '12345678901234567890123456789012',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AESEncryptKeySelector(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Primary Key (256-bit)'), findsOneWidget);
    });

    testWidgets(
      'AESDecryptKeySelector shows and allows selecting decrypt key',
      (WidgetTester tester) async {
        const storageService = AesKeyStorageService();
        await storageService.saveKey(
          AESKey(
            id: 'decrypt-1',
            name: 'Decrypt Shared Key',
            key: '12345678901234567890123456789012',
            createdAt: DateTime.now(),
          ),
        );

        AESKey? selectedKey;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: AESDecryptKeySelector(
                  primaryColor: Colors.blue,
                  onKeyChanged: (k) => selectedKey = k,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('AES Key (Decrypt)'), findsOneWidget);
        expect(find.text('Decrypt Shared Key (256-bit)'), findsOneWidget);
        expect(selectedKey?.id, equals('decrypt-1'));
      },
    );

    testWidgets('allows selecting Custom / Manual Input from dropdown', (
      WidgetTester tester,
    ) async {
      const storageService = AesKeyStorageService();
      await storageService.saveKey(
        AESKey(
          id: 'test-custom',
          name: 'Saved Key',
          key: '12345678901234567890123456789012',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AESEncryptKeySelector(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved Key (256-bit)'), findsOneWidget);

      await tester.tap(find.text('Saved Key (256-bit)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom / Manual Input').last);
      await tester.pumpAndSettle();

      expect(find.text('Custom / Manual Input'), findsOneWidget);
    });
  });

  group('CreateAESKeyDialog Widget', () {
    testWidgets('toggles manual input stably', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CreateAESKeyDialog(primaryColor: Colors.blue)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially in generate mode
      expect(find.text('Key Length'), findsOneWidget);
      expect(find.text('Manual Input / Paste'), findsOneWidget);

      // Toggle manual input switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Now in manual input mode
      expect(find.text('AES Secret Key'), findsOneWidget);
      expect(find.text('Key Length'), findsNothing);

      // Toggle back to generate mode
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Key Length'), findsOneWidget);
      expect(find.text('AES Secret Key'), findsNothing);
    });

    testWidgets('validates empty name and saves valid key', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CreateAESKeyDialog(primaryColor: Colors.blue)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Save without name -> shows snackbar
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a name for the key'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextField).first, 'My Custom AES Key');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify key was saved to storage
      const storageService = AesKeyStorageService();
      final savedKeys = await storageService.getKeys();
      expect(savedKeys.length, equals(1));
      expect(savedKeys.first.name, equals('My Custom AES Key'));
      expect(savedKeys.first.key.length, equals(32));
    });

    testWidgets(
      'renders key length dropdown without overflow on narrow screens',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: CreateAESKeyDialog(primaryColor: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('256-bit (32 chars)'), findsOneWidget);

        // Open the dropdown menu
        await tester.tap(find.text('256-bit (32 chars)'));
        await tester.pumpAndSettle();

        // Recommended label is shown in the open menu item
        expect(find.text('256-bit (32 chars) - Recommended'), findsOneWidget);
        expect(find.text('128-bit (16 chars)'), findsOneWidget);
        expect(find.text('192-bit (24 chars)'), findsOneWidget);

        // Select 128-bit
        await tester.tap(find.text('128-bit (16 chars)').last);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('128-bit (16 chars)'), findsOneWidget);
      },
    );
  });

  group('AESKeyManagementDialog Widget', () {
    testWidgets('shows saved keys and allows deletion', (
      WidgetTester tester,
    ) async {
      const storageService = AesKeyStorageService();
      await storageService.saveKey(
        AESKey(
          id: 'delete-me',
          name: 'Temporary Key',
          key: '12345678901234567890123456789012',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AESKeyManagementDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Temporary Key'), findsOneWidget);

      // Tap delete icon
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      // Confirm dialog should appear
      expect(find.text('Delete AES Key'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify deletion in storage
      final keys = await storageService.getKeys();
      expect(keys, isEmpty);
    });

    testWidgets('selecting a key calls onKeySelected and closes dialog', (
      WidgetTester tester,
    ) async {
      const storageService = AesKeyStorageService();
      final testKey = AESKey(
        id: 'select-me',
        name: 'Selected Test Key',
        key: '12345678901234567890123456789012',
        createdAt: DateTime.now(),
      );
      await storageService.saveKey(testKey);

      AESKey? chosen;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AESKeyManagementDialog(
                primaryColor: Colors.blue,
                onKeySelected: (k) {
                  chosen = k;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selected Test Key'), findsOneWidget);
      await tester.tap(find.text('Selected Test Key'));
      await tester.pumpAndSettle();

      expect(chosen?.id, equals('select-me'));
    });
  });
}
