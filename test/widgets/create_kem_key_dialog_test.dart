import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/pages/widgets/ml_kem/create_kem_key_dialog.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/services/oqs_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  OqsLoader.initialize();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('CreateKemKeyDialog Widget Tests', () {
    testWidgets('renders key name field, key size dropdown defaulting to ML-KEM-768, and action buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateKemKeyDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create KEM Key Pair'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Key Pair Name'), findsOneWidget);
      expect(find.text('ML-KEM-768 (Recommended)'), findsOneWidget);
      expect(find.text('Manual Input'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Generate'), findsOneWidget);
    });

    testWidgets('toggling Manual Input hides key size dropdown and shows key input fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateKemKeyDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle switch to manual input
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Key size dropdown should be gone
      expect(find.text('ML-KEM-768 (Recommended)'), findsNothing);
      // Key input fields should be visible
      expect(find.widgetWithText(TextField, 'Public Key'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Secret Key'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
    });

    testWidgets('generates ML-KEM-512 key when selected from dropdown', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CreateKemKeyDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter key name
      await tester.enterText(
        find.widgetWithText(TextField, 'Key Pair Name'),
        'Test_512_Key',
      );

      // Select ML-KEM-512 from dropdown
      await tester.tap(find.text('ML-KEM-768 (Recommended)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ML-KEM-512').last);
      await tester.pumpAndSettle();

      // Tap Generate
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();

      // Verify key is created in storage
      final keyPairs = await container.read(kemKeyServiceProvider).getKeyPairs();
      final created = keyPairs.firstWhere((k) => k.name == 'Test_512_Key');
      expect(created.algorithm, equals('ML-KEM-512'));
      expect(created.publicKey.length, equals(800));
      expect(created.secretKey.length, equals(1632));
    });

    testWidgets('generates ML-KEM-1024 key when selected from dropdown', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CreateKemKeyDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter key name
      await tester.enterText(
        find.widgetWithText(TextField, 'Key Pair Name'),
        'Test_1024_Key',
      );

      // Select ML-KEM-1024 from dropdown
      await tester.tap(find.text('ML-KEM-768 (Recommended)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ML-KEM-1024').last);
      await tester.pumpAndSettle();

      // Tap Generate
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();

      // Verify key is created in storage
      final keyPairs = await container.read(kemKeyServiceProvider).getKeyPairs();
      final created = keyPairs.firstWhere((k) => k.name == 'Test_1024_Key');
      expect(created.algorithm, equals('ML-KEM-1024'));
      expect(created.publicKey.length, equals(1568));
      expect(created.secretKey.length, equals(3168));
    });
  });
}
