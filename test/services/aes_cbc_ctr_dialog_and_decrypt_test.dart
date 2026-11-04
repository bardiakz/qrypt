import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/exceptions.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/resources/obfuscation/built_in_obfuscation_maps.dart';
import 'package:qrypt/resources/obfuscation/built_in_v2_maps.dart';
import 'package:qrypt/services/aes/aes_key_storage_service.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    ObfuscationService.rebuildWith({
      ObfuscationMethod.en1: builtInEn1Map,
      ObfuscationMethod.en2: builtInEn2Map,
      ObfuscationMethod.fa1: builtInFa1Map,
      ObfuscationMethod.fa2: builtInFa2Map,
      for (final m in ObfuscationMethod.values)
        if (m.isV2Mapped) m: builtInV2MapForMethod(m),
    });
    TagManager.initializeTags();
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  const base64Key256 = 'MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE='; // 44 chars, 32 bytes
  const hexKey256 =
      '3031323334353637383930313233343536373839303132333435363738393031'; // 64 chars, 32 bytes
  const standardTextKey = '12345678901234567890123456789012'; // 32 chars text

  group('AES-CBC and AES-CTR Direct Decryption with Base64 and Hex Keys', () {
    for (final method in [EncryptionMethod.aesCbc, EncryptionMethod.aesCtr]) {
      test(
        'Direct roundtrip with $method using 44-char Base64 key',
        () async {
          final ih = InputHandler();
          final qEncrypt = Qrypt.withTag(
            text: 'Secret payload with Base64 key in $method',
            encryption: method,
            obfuscation: ObfuscationMethod.none,
            compression: CompressionMethod.none,
            sign: SignMethod.none,
            useTag: true,
          );
          qEncrypt.customKey = base64Key256;
          qEncrypt.useCustomKey = true;

          final processed = await ih.handleProcess(qEncrypt);

          final qDecrypt = Qrypt.autoDecrypt(text: processed.text);
          qDecrypt.customKey = base64Key256;
          qDecrypt.useCustomKey = true;

          final deprocessed = await ih.handleDeProcess(null, qDecrypt, true);
          expect(
            deprocessed.text,
            equals('Secret payload with Base64 key in $method'),
          );
        },
      );

      test(
        'Direct roundtrip with $method using 64-char Hex key',
        () async {
          final ih = InputHandler();
          final qEncrypt = Qrypt.withTag(
            text: 'Secret payload with Hex key in $method',
            encryption: method,
            obfuscation: ObfuscationMethod.none,
            compression: CompressionMethod.none,
            sign: SignMethod.none,
            useTag: true,
          );
          qEncrypt.customKey = hexKey256;
          qEncrypt.useCustomKey = true;

          final processed = await ih.handleProcess(qEncrypt);

          final qDecrypt = Qrypt.autoDecrypt(text: processed.text);
          qDecrypt.customKey = hexKey256;
          qDecrypt.useCustomKey = true;

          final deprocessed = await ih.handleDeProcess(null, qDecrypt, true);
          expect(
            deprocessed.text,
            equals('Secret payload with Hex key in $method'),
          );
        },
      );
    }
  });

  group('AES-CBC and AES-CTR Custom Key Dialog Integration', () {
    testWidgets(
      'AES-CBC auto-decrypt prompts dialog with last-used 44-char Base64 key pre-selected and succeeds on Decrypt',
      (tester) async {
        const storage = AesKeyStorageService();
        await storage.saveKey(
          AESKey(
            id: 'kem-derived-1',
            name: 'ML-KEM Shared Key',
            key: base64Key256,
            createdAt: DateTime.now(),
          ),
        );
        await storage.setLastUsedKeyId('kem-derived-1');

        final ih = InputHandler();
        final qEncrypt = Qrypt.withTag(
          text: 'CBC test message with pre-selected key',
          encryption: EncryptionMethod.aesCbc,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: true,
        );
        qEncrypt.customKey = base64Key256;
        qEncrypt.useCustomKey = true;

        final processed = await ih.handleProcess(qEncrypt);

        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  capturedContext = ctx;
                  return const Text('Test Host');
                },
              ),
            ),
          ),
        );

        // Auto-decrypt WITHOUT pre-supplying customKey so dialog is triggered
        final autoQrypt = Qrypt.autoDecrypt(text: processed.text);
        Future<Qrypt>? deprocessFuture;

        deprocessFuture = ih.handleDeProcess(capturedContext, autoQrypt, true);
        await tester.pumpAndSettle();

        // Verify the dialog appeared with pre-selected key
        expect(find.text('AES Key Required'), findsOneWidget);
        expect(find.text('ML-KEM Shared Key (256-bit)'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);

        // Tap the Decrypt button
        await tester.tap(find.widgetWithText(ElevatedButton, 'Decrypt'));
        await tester.pumpAndSettle();

        final result = await deprocessFuture;
        expect(
          result.text,
          equals('CBC test message with pre-selected key'),
        );
      },
    );

    testWidgets(
      'AES-CTR auto-decrypt allows entering 64-char Hex key manually in dialog',
      (tester) async {
        const storage = AesKeyStorageService();
        await storage.clearAllKeys();

        final ih = InputHandler();
        final qEncrypt = Qrypt.withTag(
          text: 'CTR message with manual Hex key',
          encryption: EncryptionMethod.aesCtr,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: true,
        );
        qEncrypt.customKey = hexKey256;
        qEncrypt.useCustomKey = true;

        final processed = await ih.handleProcess(qEncrypt);

        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  capturedContext = ctx;
                  return const Text('Test Host');
                },
              ),
            ),
          ),
        );

        final autoQrypt = Qrypt.autoDecrypt(text: processed.text);
        final deprocessFuture = ih.handleDeProcess(capturedContext, autoQrypt, true);
        await tester.pumpAndSettle();

        expect(find.text('AES Key Required'), findsOneWidget);

        // Enter the 64-character Hex key into the TextField
        await tester.enterText(find.byType(TextField), hexKey256);
        await tester.pumpAndSettle();

        // Helper text should confirm valid 256-bit Hex key
        expect(find.textContaining('256-bit Hex'), findsOneWidget);

        // Tap Decrypt
        await tester.tap(find.widgetWithText(ElevatedButton, 'Decrypt'));
        await tester.pumpAndSettle();

        final result = await deprocessFuture;
        expect(
          result.text,
          equals('CTR message with manual Hex key'),
        );
      },
    );

    testWidgets(
      'Cancelling custom key dialog throws MissingKeyException',
      (tester) async {
        const storage = AesKeyStorageService();
        await storage.clearAllKeys();

        final ih = InputHandler();
        final qEncrypt = Qrypt.withTag(
          text: 'Message to cancel',
          encryption: EncryptionMethod.aesCbc,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
          useTag: true,
        );
        qEncrypt.customKey = standardTextKey;
        qEncrypt.useCustomKey = true;

        final processed = await ih.handleProcess(qEncrypt);

        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  capturedContext = ctx;
                  return const Text('Test Host');
                },
              ),
            ),
          ),
        );

        final autoQrypt = Qrypt.autoDecrypt(text: processed.text);
        Object? capturedError;
        final deprocessFuture = ih
            .handleDeProcess(capturedContext, autoQrypt, true)
            .catchError((e) {
          capturedError = e;
          return autoQrypt;
        });
        await tester.pumpAndSettle();

        expect(find.text('AES Key Required'), findsOneWidget);

        // Tap Cancel
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        await deprocessFuture;

        expect(capturedError, isA<MissingKeyException>());
        expect(
          capturedError.toString(),
          contains('Decryption cancelled: no AES key was provided.'),
        );
      },
    );
  });
}
