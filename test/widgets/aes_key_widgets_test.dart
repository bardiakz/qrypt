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
  });

  group('CreateAESKeyDialog Widget', () {
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
