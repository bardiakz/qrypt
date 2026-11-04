import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/pages/encryption_page.dart';
import 'package:qrypt/pages/widgets/kyber_widgets.dart';
import 'package:qrypt/providers/encryption_providers.dart';
import 'package:qrypt/providers/simple_state_provider.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  testWidgets(
    'ML-KEM info container and shared secret card unmount when changing to AES encryption',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          selectedEncryptionProvider.overrideWith(
            () => SimpleNotifier<EncryptionMethod>(EncryptionMethod.mlKem),
          ),
          defaultEncryptionProvider.overrideWith(
            () => SimpleNotifier<bool>(false),
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

      // In ML-KEM mode, the ML-KEM Info Container should be visible
      expect(
        find.textContaining('ML-KEM performs post-quantum key encapsulation'),
        findsOneWidget,
      );

      // Now switch encryption to AES-GCM
      container.read(selectedEncryptionProvider.notifier).state =
          EncryptionMethod.aesGcm;
      await tester.pumpAndSettle();

      // Info container must unmount immediately
      expect(
        find.textContaining('ML-KEM performs post-quantum key encapsulation'),
        findsNothing,
      );

      // MLKemSharedSecretCard must NOT be rendered in AES-GCM mode
      expect(find.byType(MLKemSharedSecretCard), findsNothing);
      expect(find.textContaining('SAVE THIS SECRET NOW'), findsNothing);
    },
  );
}
