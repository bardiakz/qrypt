import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oqs/oqs.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/pages/widgets/aes/aes_key_selector.dart';
import 'package:qrypt/pages/widgets/ml_dsa/ml_dsa_key_selector.dart';
import 'package:qrypt/pages/widgets/ml_kem/kem_key_selector.dart';
import 'package:qrypt/pages/widgets/rsa/rsa_key_selector.dart';
import 'package:qrypt/providers/aes_providers.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:qrypt/providers/kem_providers.dart';
import 'package:qrypt/providers/ml_dsa_providers.dart';
import 'package:qrypt/providers/resource_providers.dart';
import 'package:qrypt/providers/rsa_providers.dart';
import 'package:qrypt/providers/simple_state_provider.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({
      'disclaimer_accepted_v1': 'true',
    });
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  setUp(() {
    clipboardText = null;
    FlutterSecureStorage.setMockInitialValues({
      'disclaimer_accepted_v1': 'true',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Asymmetric Selector Public Key Share Shortcut', () {
    testWidgets(
      'RSAKeySelector hides Share button when empty and shares the selected public key only',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              rsaKeyPairsProvider.overrideWith((ref) => Future.value([])),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: RSAEncryptKeySelector(primaryColor: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.qr_code_2), findsNothing);

        final aliceRsa = RSAKeyPair(
          id: 'rsa-1',
          name: 'AliceRSA',
          publicKey:
              '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A\n-----END PUBLIC KEY-----',
          privateKey:
              '-----BEGIN PRIVATE KEY-----\nSECRET_PRIVATE_KEY_DO_NOT_SHARE\n-----END PRIVATE KEY-----',
          createdAt: DateTime.now(),
        );
        final workRsa = RSAKeyPair(
          id: 'rsa-2',
          name: 'WorkRSA',
          publicKey:
              '-----BEGIN PUBLIC KEY-----\nWORKRSAWORKRSAWORKRSAWORKRSA\n-----END PUBLIC KEY-----',
          privateKey:
              '-----BEGIN PRIVATE KEY-----\nWORK_SECRET_PRIVATE_KEY\n-----END PRIVATE KEY-----',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('rsa-populated'),
            overrides: [
              rsaKeyPairsProvider.overrideWith(
                (ref) => Future.value([aliceRsa, workRsa]),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: RSAEncryptKeySelector(primaryColor: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final shareBtn = find.byTooltip('Share Public Key (AliceRSA)');
        expect(shareBtn, findsOneWidget);

        // Switch key pair via the card dropdown before sharing
        await tester.tap(find.byType(DropdownButtonFormField<RSAKeyPair>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('WorkRSA').last);
        await tester.pumpAndSettle();

        final updatedShareBtn = find.byTooltip('Share Public Key (WorkRSA)');
        expect(updatedShareBtn, findsOneWidget);

        await tester.tap(updatedShareBtn);
        await tester.pumpAndSettle();

        expect(find.text('RSA Public Key: WorkRSA'), findsOneWidget);

        await tester.tap(find.text('Copy to Clipboard'));
        await tester.pumpAndSettle();

        expect(clipboardText, equals(workRsa.publicKey));
        expect(clipboardText, isNot(contains('PRIVATE_KEY')));
      },
    );

    testWidgets(
      'KemKeySelector hides Share button when empty and shares only public key when populated',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              kemKeyPairsProvider.overrideWith((ref) => Future.value([])),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: KemDecryptKeySelector(primaryColor: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.qr_code_2), findsNothing);

        final pubBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
        final secBytes = Uint8List.fromList([99, 88, 77, 66, 55]);
        final sampleKem = QryptKEMKeyPair(
          id: 'kem-1',
          name: 'BobKEM',
          algorithm: 'ML-KEM-768',
          createdAt: DateTime.now(),
          kemKeyPair: KEMKeyPair(publicKey: pubBytes, secretKey: secBytes),
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('kem-populated'),
            overrides: [
              kemKeyPairsProvider.overrideWith(
                (ref) => Future.value([sampleKem]),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: KemDecryptKeySelector(primaryColor: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final shareBtn = find.byTooltip('Share Public Key (BobKEM)');
        expect(shareBtn, findsOneWidget);

        await tester.tap(shareBtn);
        await tester.pumpAndSettle();

        expect(find.text('ML-KEM Public Key: BobKEM'), findsOneWidget);

        await tester.tap(find.text('Copy to Clipboard'));
        await tester.pumpAndSettle();

        expect(clipboardText, equals(base64Encode(pubBytes)));
        expect(clipboardText, isNot(equals(base64Encode(secBytes))));
      },
    );

    testWidgets(
      'MlDsaKeySelector hides Share button when empty and shares only public key when populated',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mlDsaKeyPairsProvider.overrideWith((ref) => Future.value([])),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: MlDsaSignKeySelector(primaryColor: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.qr_code_2), findsNothing);

        final pubBytes = Uint8List.fromList([1, 3, 5, 7, 9]);
        final secBytes = Uint8List.fromList([2, 4, 6, 8, 10]);
        final sampleDsa = QryptMLDSAKeyPair.fromComponents(
          id: 'dsa-1',
          name: 'CarolDSA',
          algorithm: 'ML-DSA-65',
          publicKey: pubBytes,
          secretKey: secBytes,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('dsa-populated'),
            overrides: [
              mlDsaKeyPairsProvider.overrideWith(
                (ref) => Future.value([sampleDsa]),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: MlDsaSignKeySelector(primaryColor: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final shareBtn = find.byTooltip('Share Public Key (CarolDSA)');
        expect(shareBtn, findsOneWidget);

        await tester.tap(shareBtn);
        await tester.pumpAndSettle();

        expect(find.text('ML-DSA Public Key: CarolDSA'), findsOneWidget);

        await tester.tap(find.text('Copy to Clipboard'));
        await tester.pumpAndSettle();

        expect(clipboardText, equals(base64Encode(pubBytes)));
        expect(clipboardText, isNot(equals(base64Encode(secBytes))));
      },
    );

    testWidgets('AESKeySelector never renders a Share Public Key QR shortcut', (
      WidgetTester tester,
    ) async {
      final aesKey = AESKey(
        id: 'aes-1',
        name: 'SharedSecret',
        key: '12345678901234567890123456789012',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aesKeysProvider.overrideWith((ref) => Future.value([aesKey])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AESEncryptKeySelector(primaryColor: Colors.blue),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Share Public Key'), findsNothing);
      expect(find.byIcon(Icons.qr_code_2), findsNothing);
    });
  });

  group('EncryptionPage Public Key Share Shortcuts', () {
    testWidgets(
      'Manual Encrypt ML-KEM and RSA show key name, omit Change for 1 key, and let user choose among multiple keys',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final rsaPrimary = RSAKeyPair(
          id: 'enc-rsa-1',
          name: 'MyEncryptRSA',
          publicKey:
              '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A\n-----END PUBLIC KEY-----',
          privateKey: 'PRIVATE_RSA_SECRET_1',
          createdAt: DateTime.now(),
        );
        final rsaBackup = RSAKeyPair(
          id: 'enc-rsa-2',
          name: 'BackupRSA',
          publicKey:
              '-----BEGIN PUBLIC KEY-----\nBACKUPRSABACKUPRSABACKUPRSA\n-----END PUBLIC KEY-----',
          privateKey: 'PRIVATE_RSA_SECRET_2',
          createdAt: DateTime.now(),
        );
        final kemPub1 = Uint8List.fromList([11, 22, 33, 44]);
        final kemPub2 = Uint8List.fromList([55, 66, 77, 88]);
        final kemPrimary = QryptKEMKeyPair(
          id: 'enc-kem-1',
          name: 'MyEncryptKEM',
          algorithm: 'ML-KEM-768',
          createdAt: DateTime.now(),
          kemKeyPair: KEMKeyPair(
            publicKey: kemPub1,
            secretKey: Uint8List.fromList([99, 98, 97]),
          ),
        );
        final kemBackup = QryptKEMKeyPair(
          id: 'enc-kem-2',
          name: 'BackupKEM',
          algorithm: 'ML-KEM-1024',
          createdAt: DateTime.now(),
          kemKeyPair: KEMKeyPair(
            publicKey: kemPub2,
            secretKey: Uint8List.fromList([96, 95, 94]),
          ),
        );

        // Single RSA key -> no Change button; Multiple ML-KEM keys -> Change + Share
        final container = ProviderContainer(
          overrides: [
            defaultEncryptionProvider.overrideWith(
              () => SimpleNotifier<bool>(false),
            ),
            selectedEncryptionProvider.overrideWith(
              () => SimpleNotifier<EncryptionMethod>(EncryptionMethod.mlKem),
            ),
            rsaKeyPairsProvider.overrideWith(
              (ref) => Future.value([rsaPrimary]),
            ),
            kemKeyPairsProvider.overrideWith(
              (ref) => Future.value([kemPrimary, kemBackup]),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: EncryptionPage()),
          ),
        );
        await tester.pumpAndSettle();

        // Starts retracted with summary, expands on tap, and retracts again
        expect(find.text('Your ML-KEM Public Key'), findsOneWidget);
        expect(find.text('• MyEncryptKEM'), findsOneWidget);
        expect(find.byTooltip('Expand'), findsOneWidget);

        await tester.tap(find.text('Your ML-KEM Public Key'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Collapse'), findsOneWidget);
        expect(find.text('MyEncryptKEM'), findsOneWidget);
        expect(find.byTooltip('Change ML-KEM key pair'), findsOneWidget);

        // Retract and re-expand verifies clean toggle state
        await tester.tap(find.text('Your ML-KEM Public Key'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Expand'), findsOneWidget);

        await tester.tap(find.text('Your ML-KEM Public Key'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Collapse'), findsOneWidget);

        // Choose BackupKEM via unified key picker dialog
        await tester.tap(find.byTooltip('Change ML-KEM key pair'));
        await tester.pumpAndSettle();

        expect(find.text('Select ML-KEM Key'), findsOneWidget);
        expect(find.text('MyEncryptKEM'), findsWidgets);
        expect(find.text('BackupKEM'), findsOneWidget);

        await tester.tap(find.text('BackupKEM'));
        await tester.pumpAndSettle();

        expect(find.text('BackupKEM'), findsOneWidget);

        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();
        expect(find.text('ML-KEM Public Key: BackupKEM'), findsOneWidget);

        await tester.tap(find.text('Copy to Clipboard'));
        await tester.pumpAndSettle();
        expect(clipboardText, equals(base64Encode(kemPub2)));

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Switch to RSA Encrypt mode (same card stays expanded or expands on tap)
        container.read(selectedEncryptionProvider.notifier).state =
            EncryptionMethod.rsa;
        await tester.pumpAndSettle();

        expect(find.text('Your RSA Public Key'), findsOneWidget);
        if (find.byTooltip('Expand').evaluate().isNotEmpty) {
          await tester.tap(find.text('Your RSA Public Key'));
          await tester.pumpAndSettle();
        }
        expect(find.text('MyEncryptRSA'), findsOneWidget);
        expect(find.byTooltip('Change RSA key pair'), findsNothing);

        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();
        expect(find.text('RSA Public Key: MyEncryptRSA'), findsOneWidget);

        await tester.tap(find.text('Copy to Clipboard'));
        await tester.pumpAndSettle();
        expect(clipboardText, equals(rsaPrimary.publicKey));
        expect(clipboardText, isNot(contains('PRIVATE_RSA_SECRET')));

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Verify multiple RSA keys expose switcher pill after expanding
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('multi-rsa-encrypt'),
            overrides: [
              defaultEncryptionProvider.overrideWith(
                () => SimpleNotifier<bool>(false),
              ),
              selectedEncryptionProvider.overrideWith(
                () => SimpleNotifier<EncryptionMethod>(EncryptionMethod.rsa),
              ),
              rsaKeyPairsProvider.overrideWith(
                (ref) => Future.value([rsaPrimary, rsaBackup]),
              ),
            ],
            child: const MaterialApp(home: EncryptionPage()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Your RSA Public Key'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Change RSA key pair'), findsOneWidget);
        await tester.tap(find.byTooltip('Change RSA key pair'));
        await tester.pumpAndSettle();

        expect(find.text('Select RSA Key'), findsOneWidget);
        await tester.tap(find.text('BackupRSA'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();
        expect(find.text('RSA Public Key: BackupRSA'), findsOneWidget);
      },
    );

    testWidgets(
      'Auto-Detect Decrypt mode shows key names for single keys and chooser dialog for multiple keys',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(900, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 1. Empty asymmetric keys -> bar stays hidden
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('autodetect-empty'),
            overrides: [
              appModeProvider.overrideWith(
                () => SimpleNotifier<AppMode>(AppMode.decrypt),
              ),
              rsaKeyPairsProvider.overrideWith((ref) => Future.value([])),
              kemKeyPairsProvider.overrideWith((ref) => Future.value([])),
              mlDsaKeyPairsProvider.overrideWith((ref) => Future.value([])),
            ],
            child: const MaterialApp(home: EncryptionPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Share Public Key'), findsNothing);

        // 2. Single ML-KEM & ML-DSA keys (explicit names) + multiple RSA keys (chooser)
        final rsaWork = RSAKeyPair(
          id: 'dec-rsa-1',
          name: 'WorkRSA',
          publicKey:
              '-----BEGIN PUBLIC KEY-----\nWORKRSA\n-----END PUBLIC KEY-----',
          privateKey: 'WORK_PRIVATE_DO_NOT_SHARE',
          createdAt: DateTime.now(),
        );
        final rsaPersonal = RSAKeyPair(
          id: 'dec-rsa-2',
          name: 'PersonalRSA',
          publicKey:
              '-----BEGIN PUBLIC KEY-----\nPERSONALRSA\n-----END PUBLIC KEY-----',
          privateKey: 'PERSONAL_PRIVATE_DO_NOT_SHARE',
          createdAt: DateTime.now(),
        );
        final dsaPub = Uint8List.fromList([7, 8, 9, 10]);
        final dsaKey = QryptMLDSAKeyPair.fromComponents(
          id: 'dec-dsa-1',
          name: 'QuickDSA',
          algorithm: 'ML-DSA-65',
          publicKey: dsaPub,
          secretKey: Uint8List.fromList([77, 88, 99]),
          createdAt: DateTime.now(),
        );
        final kemPub = Uint8List.fromList([1, 2, 3, 4]);
        final kemKey = QryptKEMKeyPair(
          id: 'dec-kem-1',
          name: 'QuickKEM',
          algorithm: 'ML-KEM-768',
          createdAt: DateTime.now(),
          kemKeyPair: KEMKeyPair(
            publicKey: kemPub,
            secretKey: Uint8List.fromList([55, 66]),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('autodetect-populated'),
            overrides: [
              appModeProvider.overrideWith(
                () => SimpleNotifier<AppMode>(AppMode.decrypt),
              ),
              rsaKeyPairsProvider.overrideWith(
                (ref) => Future.value([rsaWork, rsaPersonal]),
              ),
              kemKeyPairsProvider.overrideWith((ref) => Future.value([kemKey])),
              mlDsaKeyPairsProvider.overrideWith(
                (ref) => Future.value([dsaKey]),
              ),
            ],
            child: const MaterialApp(home: EncryptionPage()),
          ),
        );
        await tester.pumpAndSettle();

        // Starts retracted with summary, expands on tap to reveal rows
        expect(find.text('Share Public Key'), findsOneWidget);
        expect(find.text('• RSA • ML-KEM • ML-DSA'), findsOneWidget);
        expect(find.byTooltip('Expand'), findsOneWidget);

        await tester.tap(find.text('Share Public Key'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Collapse'), findsOneWidget);
        expect(find.text('WorkRSA'), findsOneWidget);
        expect(find.text('QuickKEM'), findsOneWidget);
        expect(find.text('QuickDSA'), findsOneWidget);

        // Single-key row opens QR directly
        await tester.tap(find.byTooltip('Share ML-DSA public key (QuickDSA)'));
        await tester.pumpAndSettle();
        expect(find.text('ML-DSA Public Key: QuickDSA'), findsOneWidget);

        await tester.tap(find.text('Copy to Clipboard'));
        await tester.pumpAndSettle();
        expect(clipboardText, equals(base64Encode(dsaPub)));

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Multi-key switcher lets user change the selected key via picker dialog
        await tester.tap(find.byTooltip('Change RSA key pair'));
        await tester.pumpAndSettle();

        expect(find.text('Select RSA Key'), findsOneWidget);
        expect(find.text('WorkRSA'), findsWidgets);
        expect(find.text('PersonalRSA'), findsOneWidget);

        await tester.tap(find.text('PersonalRSA'));
        await tester.pumpAndSettle();

        // Row updates immediately to display the newly selected key
        expect(find.text('PersonalRSA'), findsOneWidget);
        expect(find.text('WorkRSA'), findsNothing);

        // Tapping Share on the RSA row shares PersonalRSA's public key
        await tester.tap(find.byTooltip('Share RSA public key (PersonalRSA)'));
        await tester.pumpAndSettle();

        expect(find.text('RSA Public Key: PersonalRSA'), findsOneWidget);

        await tester.tap(find.text('Copy to Clipboard'));
        await tester.pumpAndSettle();
        expect(clipboardText, equals(rsaPersonal.publicKey));
        expect(clipboardText, isNot(contains('PRIVATE')));
      },
    );

    testWidgets(
      'Shortcuts handle long key names and dark theme cleanly without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final longKem1 = QryptKEMKeyPair(
          id: 'mobile-kem-1',
          name: 'VeryLongMobileKeyPairNameExampleForWidthTest',
          algorithm: 'ML-KEM-768',
          createdAt: DateTime.now(),
          kemKeyPair: KEMKeyPair(
            publicKey: Uint8List.fromList([1, 2, 3]),
            secretKey: Uint8List.fromList([4, 5, 6]),
          ),
        );
        final longKem2 = QryptKEMKeyPair(
          id: 'mobile-kem-2',
          name: 'SecondMobileKeyPair',
          algorithm: 'ML-KEM-1024',
          createdAt: DateTime.now(),
          kemKeyPair: KEMKeyPair(
            publicKey: Uint8List.fromList([7, 8, 9]),
            secretKey: Uint8List.fromList([10, 11, 12]),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              defaultEncryptionProvider.overrideWith(
                () => SimpleNotifier<bool>(false),
              ),
              selectedEncryptionProvider.overrideWith(
                () => SimpleNotifier<EncryptionMethod>(EncryptionMethod.mlKem),
              ),
              kemKeyPairsProvider.overrideWith(
                (ref) => Future.value([longKem1, longKem2]),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const EncryptionPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Your ML-KEM Public Key'),
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Your ML-KEM Public Key'), findsOneWidget);
        await tester.tap(find.text('Your ML-KEM Public Key'));
        await tester.pumpAndSettle();
        expect(find.text('Share'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('mobile-autodetect'),
            overrides: [
              appModeProvider.overrideWith(
                () => SimpleNotifier<AppMode>(AppMode.decrypt),
              ),
              kemKeyPairsProvider.overrideWith((ref) => Future.value([longKem1])),
              rsaKeyPairsProvider.overrideWith((ref) => Future.value([])),
              mlDsaKeyPairsProvider.overrideWith((ref) => Future.value([])),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const EncryptionPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Share Public Key'),
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Share Public Key'), findsOneWidget);
        await tester.tap(find.text('Share Public Key'));
        await tester.pumpAndSettle();
        expect(find.text('Share'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
