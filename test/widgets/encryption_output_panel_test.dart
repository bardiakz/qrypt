import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/pages/widgets/encryption_output_panel.dart';
import 'package:qrypt/pages/widgets/mode_switch.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:qrypt/providers/resource_providers.dart';
import 'package:qrypt/providers/simple_state_provider.dart';
import 'package:qrypt/services/clipboard_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;

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
    ClipboardSecurityService.cancelPendingClear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('EncryptionOutputPanel Widget Tests', () {
    testWidgets(
      'Encrypt ML-KEM mode shows ciphertext title, QR share, copy, and clear actions',
      (WidgetTester tester) async {
        var cleared = false;
        final encrypted = Qrypt(
          text: 'CIPHERTEXT_PAYLOAD_123',
          encryption: EncryptionMethod.mlKem,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.none,
          sign: SignMethod.none,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              processedEncryptProvider.overrideWith(
                () => SimpleNotifier<Qrypt>(encrypted),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EncryptionOutputPanel(
                    primaryColor: Colors.blue,
                    isEncryptMode: true,
                    isMLKemMode: true,
                    shouldShowKemSecret: false,
                    mlKemSharedSecret: '',
                    lastDecryptSummary: null,
                    onClearOutput: () => cleared = true,
                    onKemKeySaved: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Ciphertext Output (send to recipient)'),
          findsOneWidget,
        );
        expect(find.text('CIPHERTEXT_PAYLOAD_123'), findsOneWidget);
        expect(find.byTooltip('Share ciphertext as QR code'), findsOneWidget);

        await tester.tap(find.byTooltip('Copy output (Ctrl+Shift+C)'));
        await tester.pumpAndSettle();
        expect(clipboardText, equals('CIPHERTEXT_PAYLOAD_123'));

        await tester.tap(find.byTooltip('Share ciphertext as QR code'));
        await tester.pumpAndSettle();
        expect(find.text('Ciphertext QR Code'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Clear output'));
        await tester.pumpAndSettle();
        expect(cleared, isTrue);
      },
    );

    testWidgets(
      'Decrypt mode hides QR share, renders empty placeholder, and shows pipeline summary badges',
      (WidgetTester tester) async {
        final summary = Qrypt(
          text: 'DECRYPTED_SECRET_MSG',
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.en2,
          compression: CompressionMethod.gZip,
          sign: SignMethod.mlDsa,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              processedDecryptProvider.overrideWith(
                () => SimpleNotifier<Qrypt>(summary),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EncryptionOutputPanel(
                    primaryColor: Colors.blue,
                    isEncryptMode: false,
                    isMLKemMode: false,
                    shouldShowKemSecret: false,
                    mlKemSharedSecret: '',
                    lastDecryptSummary: summary,
                    onClearOutput: () {},
                    onKemKeySaved: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Output'), findsOneWidget);
        expect(find.byTooltip('Share ciphertext as QR code'), findsNothing);
        expect(find.text('Signature Verified (ML-DSA)'), findsOneWidget);
        expect(find.textContaining('AES-GCM • GZIP •'), findsOneWidget);
        expect(find.text('DECRYPTED_SECRET_MSG'), findsOneWidget);

        await tester.tap(find.byTooltip('Copy output (Ctrl+Shift+C)'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(clipboardText, equals('DECRYPTED_SECRET_MSG'));
        ClipboardSecurityService.cancelPendingClear();
      },
    );
  });

  group('Narrow Screen Action Button Overflow', () {
    testWidgets(
      'Encapsulate & Encrypt and modeSwitch fit narrow viewports without RenderFlex overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              defaultEncryptionProvider.overrideWith(
                () => SimpleNotifier<bool>(false),
              ),
              selectedEncryptionProvider.overrideWith(
                () => SimpleNotifier<EncryptionMethod>(EncryptionMethod.mlKem),
              ),
            ],
            child: const MaterialApp(home: EncryptionPage()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Encapsulate & Encrypt'),
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Encapsulate & Encrypt'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Verify the header modeSwitch scales cleanly even on ultra-narrow 320px screens
        final encCtrl = TextEditingController();
        final decCtrl = TextEditingController();
        addTearDown(encCtrl.dispose);
        addTearDown(decCtrl.dispose);

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('mode-switch-320'),
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: Consumer(
                      builder: (context, ref, _) {
                        return Row(
                          children: [
                            const IconButton(
                              onPressed: null,
                              icon: Icon(Icons.vpn_key_outlined),
                            ),
                            Expanded(
                              child: Center(
                                child: modeSwitch(
                                  context,
                                  AppMode.encrypt,
                                  Colors.blue,
                                  ref,
                                  encCtrl,
                                  decCtrl,
                                ),
                              ),
                            ),
                            const IconButton(
                              onPressed: null,
                              icon: Icon(Icons.settings),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Encrypt'), findsOneWidget);
        expect(find.text('Decrypt'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
