import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrypt/main.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.loadFromString(
      envString: 'ENCRYPTION_KEY=dummy_test_key_for_testing_32b\n',
    );
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  testWidgets('App launches and renders EncryptionPage smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
  });
}
