import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/pages/widgets/rsa/RSA_key_selection_dialog.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:qrypt/providers/resource_providers.dart';
import 'package:qrypt/providers/simple_state_provider.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.loadAllTags();
  });

  group('Scoped Key Input Providers Unit Tests', () {
    test('providers initialize to empty string and can be mutated via notifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify rsaDecryptPublicKeyProvider
      expect(container.read(rsaDecryptPublicKeyProvider), '');
      container.read(rsaDecryptPublicKeyProvider.notifier).state = 'test-rsa-key';
      expect(container.read(rsaDecryptPublicKeyProvider), 'test-rsa-key');

      // Verify mlDsaVerifyPublicKeyProvider and alias
      expect(container.read(mlDsaVerifyPublicKeyProvider), '');
      container.read(mlDsaVerifyPublicKeyProvider.notifier).state = 'test-dsa-key';
      expect(container.read(mlDsaVerifyPublicKeyProvider), 'test-dsa-key');
      expect(container.read(verifyMlDsaPublicKeyProvider), 'test-dsa-key');

      // Verify kemDecryptPublicKeyProvider and alias
      expect(container.read(kemDecryptPublicKeyProvider), '');
      container.read(kemDecryptPublicKeyProvider.notifier).state = 'test-kem-key';
      expect(container.read(kemDecryptPublicKeyProvider), 'test-kem-key');
      expect(container.read(decryptKemPublicKeyProvider), 'test-kem-key');
    });

    test('container isolation ensures scoped independent state', () {
      final containerA = ProviderContainer();
      final containerB = ProviderContainer();
      addTearDown(containerA.dispose);
      addTearDown(containerB.dispose);

      containerA.read(rsaDecryptPublicKeyProvider.notifier).state = 'key-a';
      containerB.read(rsaDecryptPublicKeyProvider.notifier).state = 'key-b';

      expect(containerA.read(rsaDecryptPublicKeyProvider), 'key-a');
      expect(containerB.read(rsaDecryptPublicKeyProvider), 'key-b');
    });
  });

  group('EncryptionPage Key Input Sync & Provider Reactivity', () {
    testWidgets('syncs rsaDecryptPublicKeyProvider when entering text in decrypt mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWith(
            () => SimpleNotifier<AppMode>(AppMode.decrypt),
          ),
          defaultEncryptionProvider.overrideWith(
            () => SimpleNotifier<bool>(false),
          ),
          autoDetectTagProvider.overrideWith(
            () => SimpleNotifier<bool>(false),
          ),
          selectedEncryptionProvider.overrideWith(
            () => SimpleNotifier<EncryptionMethod>(EncryptionMethod.rsaSign),
          ),
        ],
      );
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

      // Find public key field for RSA Sign decrypt
      final pubKeyField = find.widgetWithText(TextField, 'Public Key');
      expect(pubKeyField, findsOneWidget);

      const testPemKey =
          '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A\n-----END PUBLIC KEY-----';
      await tester.enterText(pubKeyField, testPemKey);
      await tester.pumpAndSettle();

      expect(container.read(rsaDecryptPublicKeyProvider), testPemKey);
    });

    testWidgets('updating rsaDecryptPublicKeyProvider updates text controller in UI',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWith(
            () => SimpleNotifier<AppMode>(AppMode.decrypt),
          ),
          defaultEncryptionProvider.overrideWith(
            () => SimpleNotifier<bool>(false),
          ),
          autoDetectTagProvider.overrideWith(
            () => SimpleNotifier<bool>(false),
          ),
          selectedEncryptionProvider.overrideWith(
            () => SimpleNotifier<EncryptionMethod>(EncryptionMethod.rsaSign),
          ),
        ],
      );
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

      const newKey =
          '-----BEGIN PUBLIC KEY-----\nUPDATEDKEYTEST\n-----END PUBLIC KEY-----';
      container.read(rsaDecryptPublicKeyProvider.notifier).state = newKey;
      await tester.pumpAndSettle();

      expect(find.text(newKey), findsOneWidget);
    });
  });

  group('RSAKeySelectionDialog onPublicKeySelected callback', () {
    testWidgets('triggers onPublicKeySelected when public key text is entered',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      String? capturedKey;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: RSAKeySelectionDialog(
                primaryColor: Colors.blue,
                publicKeyRequired: true,
                onPublicKeySelected: (key) {
                  capturedKey = key;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pubKeyField = find.widgetWithText(TextField, 'Public Key');
      expect(pubKeyField, findsOneWidget);

      const testKey = '-----BEGIN PUBLIC KEY-----\nMYPUBLICKEY\n-----END PUBLIC KEY-----';
      await tester.enterText(pubKeyField, testKey);
      await tester.pumpAndSettle();

      expect(capturedKey, testKey);
      expect(container.read(rsaDecryptPublicKeyProvider), testKey);
    });
  });

  group('InputHandler handleDecrypt with rsaSign', () {
    test('passes rsaSenderPublicKey from qrypt parameter without reading globals',
        () async {
      final rsaService = RSAKeyService();
      final senderKeyPair = await rsaService.generateKeyPair(
        'Sender',
        keySize: 2048,
      );
      final receiverKeyPair = await rsaService.generateKeyPair(
        'Receiver',
        keySize: 2048,
      );
      final wrongKeyPair = await rsaService.generateKeyPair(
        'Wrong',
        keySize: 2048,
      );

      final ih = InputHandler();

      // Encrypt message with rsaSign
      final encryptQrypt = Qrypt(
        text: 'Secret payload for refactor test',
        encryption: EncryptionMethod.rsaSign,
        obfuscation: ObfuscationMethod.b64,
        compression: CompressionMethod.none,
        sign: SignMethod.none,
      );
      encryptQrypt.compressedText = utf8.encode('Secret payload for refactor test');
      encryptQrypt.rsaKeyPair = senderKeyPair; // Sender signs
      encryptQrypt.rsaReceiverPublicKey = receiverKeyPair.publicKey; // Receiver encrypts

      final encryptedQrypt = await ih.handleEncrypt(encryptQrypt);

      // Decrypt with correct keys explicitly set on qrypt object
      final correctDecryptQrypt = Qrypt(
        text: encryptedQrypt.text,
        encryption: EncryptionMethod.rsaSign,
        obfuscation: ObfuscationMethod.b64,
        compression: CompressionMethod.none,
        sign: SignMethod.none,
      );
      correctDecryptQrypt.rsaKeyPair = receiverKeyPair;
      correctDecryptQrypt.rsaSenderPublicKey = senderKeyPair.publicKey;

      final decrypted = await ih.handleDecrypt(correctDecryptQrypt, null);
      final decryptedText = utf8.decode(decrypted.deCompressedText);
      expect(decryptedText, 'Secret payload for refactor test');

      // Decrypt with wrong sender public key set explicitly on qrypt object
      final wrongDecryptQrypt = Qrypt(
        text: encryptedQrypt.text,
        encryption: EncryptionMethod.rsaSign,
        obfuscation: ObfuscationMethod.b64,
        compression: CompressionMethod.none,
        sign: SignMethod.none,
      );
      wrongDecryptQrypt.rsaKeyPair = receiverKeyPair;
      wrongDecryptQrypt.rsaSenderPublicKey = wrongKeyPair.publicKey;

      expect(
        () => ih.handleDecrypt(wrongDecryptQrypt, null),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('RSA+Sign decryption failed'),
          ),
        ),
      );
    });
  });
}
