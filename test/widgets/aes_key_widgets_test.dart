import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/pages/widgets/aes/aes_key_management_dialog.dart';
import 'package:qrypt/pages/widgets/aes/aes_key_selector.dart';
import 'package:qrypt/pages/widgets/aes/create_aes_key_dialog.dart';
import 'package:qrypt/providers/aes_providers.dart';
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
  });
}
