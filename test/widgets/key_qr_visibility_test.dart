import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oqs/oqs.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/pages/widgets/aes/aes_key_management_dialog.dart';
import 'package:qrypt/pages/widgets/kyber_widgets.dart';
import 'package:qrypt/pages/widgets/ml_dsa/ml_dsa_key_management_dialog.dart';
import 'package:qrypt/pages/widgets/ml_kem/kem_key_management_dialog.dart';
import 'package:qrypt/pages/widgets/rsa/rsa_key_management_dialog.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/providers/ml_dsa_providers.dart';
import 'package:qrypt/providers/resource_providers.dart';
import 'package:qrypt/providers/rsa_providers.dart';
import 'package:qrypt/services/aes/aes_key_storage_service.dart';
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

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'disclaimer_accepted_v1': 'true',
    });
  });

  group('QR Code Visibility Invariants: Public Key Presence vs Secret Key Absence', () {
    testWidgets('RSAKeyManagementDialog export shows QR for Public Key but NOT Private Key', (
      WidgetTester tester,
    ) async {
      final sampleRsa = RSAKeyPair(
        id: 'test-rsa-1',
        name: 'MyRSAKey',
        publicKey:
            '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A\n-----END PUBLIC KEY-----',
        privateKey:
            '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0\n-----END RSA PRIVATE KEY-----',
        createdAt: DateTime.now(),
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

      // Open popup menu on key tile
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Export menu item
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      // Verify export dialog opened
      expect(find.text('Export MyRSAKey'), findsOneWidget);

      // Invariant: Public key row MUST have QR button
      expect(find.byTooltip('Show Public Key QR'), findsOneWidget);

      // Invariant: Private key row MUST NOT have QR button
      expect(find.byTooltip('Show Private Key QR'), findsNothing);
      expect(find.widgetWithIcon(IconButton, Icons.qr_code_2), findsNWidgets(1));
    });

    testWidgets('KemKeyManagementDialog export shows QR for Public Key but NOT Secret Key', (
      WidgetTester tester,
    ) async {
      final sampleKem = QryptKEMKeyPair(
        id: 'test-kem-1',
        name: 'MyKEMKey',
        algorithm: 'ML-KEM-768',
        createdAt: DateTime.now(),
        kemKeyPair: KEMKeyPair(
          publicKey: Uint8List.fromList([1, 2, 3, 4]),
          secretKey: Uint8List.fromList([5, 6, 7, 8]),
        ),
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

      // Open popup menu on key tile
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Export menu item
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      // Verify export dialog opened
      expect(find.text('Export MyKEMKey'), findsOneWidget);

      // Invariant: Public key row MUST have QR button
      expect(find.byTooltip('Show Public Key QR'), findsOneWidget);

      // Invariant: Secret key row MUST NOT have QR button
      expect(find.byTooltip('Show Secret Key QR'), findsNothing);
      expect(find.widgetWithIcon(IconButton, Icons.qr_code_2), findsNWidgets(1));
    });

    testWidgets('MlDsaKeyManagementDialog export shows QR for Public Key but NOT Secret Key', (
      WidgetTester tester,
    ) async {
      final sampleDsa = QryptMLDSAKeyPair.fromComponents(
        id: 'test-dsa-1',
        name: 'MyDSAKey',
        algorithm: 'ML-DSA-65',
        publicKey: Uint8List.fromList([1, 2, 3, 4]),
        secretKey: Uint8List.fromList([5, 6, 7, 8]),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mlDsaKeyPairsProvider.overrideWith((ref) => Future.value([sampleDsa])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MlDsaKeyManagementDialog(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup menu on key tile
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap Export menu item
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      // Verify export dialog opened
      expect(find.text('Export MyDSAKey'), findsOneWidget);

      // Invariant: Public key row MUST have QR button
      expect(find.byTooltip('Show Public Key QR'), findsOneWidget);

      // Invariant: Secret key row MUST NOT have QR button
      expect(find.byTooltip('Show Secret Key QR'), findsNothing);
      expect(find.widgetWithIcon(IconButton, Icons.qr_code_2), findsNWidgets(1));
    });

    testWidgets('AESKeyManagementDialog has NO QR buttons on symmetric key tiles', (
      WidgetTester tester,
    ) async {
      const storageService = AesKeyStorageService();
      await storageService.saveKey(
        AESKey(
          id: 'test-aes-1',
          name: 'Symmetric Secret Key',
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

      expect(find.text('Symmetric Secret Key'), findsOneWidget);

      // Invariant: No QR button anywhere in the dialog for symmetric keys
      expect(find.byIcon(Icons.qr_code_2), findsNothing);
      expect(find.byTooltip('Show QR code'), findsNothing);
    });

    testWidgets('MLKemSharedSecretCard has NO QR button for symmetric shared secret', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MLKemSharedSecretCard(
                context: context,
                primaryColor: Colors.blue,
                sharedSecretBase64: 'dGVzdC1zaGFyZWQtc2VjcmV0LWJhc2U2NA==',
                isSender: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Invariant: Shared secret only allows Copy and Save as AES Key; NO QR button
      expect(find.text('Copy Key'), findsOneWidget);
      expect(find.text('Save as AES Key'), findsOneWidget);
      expect(find.text('QR Code'), findsNothing);
      expect(find.byIcon(Icons.qr_code_2), findsNothing);
    });

    testWidgets('EncryptionPage Output section shows QR in encrypt mode, hides QR in decrypt mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Encrypt mode: QR button MUST be present
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EncryptionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Share ciphertext as QR code'), findsOneWidget);

      // 2. Switch to Decrypt mode: QR button MUST be absent
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EncryptionPage)),
      );
      container.read(appModeProvider.notifier).state = AppMode.decrypt;
      await tester.pumpAndSettle();

      // Invariant: Decrypt mode (plaintext output) MUST NOT show QR share button
      expect(find.byTooltip('Share ciphertext as QR code'), findsNothing);
      expect(find.byTooltip('Share output as QR code'), findsNothing);
    });
  });
}
