import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qrypt/models/custom_obfuscation_profile.dart';
import 'package:qrypt/pages/settings_page.dart';
import 'package:qrypt/pages/widgets/custom_map_picker_dialog.dart';
import 'package:qrypt/services/obfuscation/custom_map_storage_service.dart';
import 'package:qrypt/services/obfuscation/v2_map_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Qrypt',
      packageName: 'com.example.qrypt',
      version: '5.5.0',
      buildNumber: '22',
      buildSignature: '',
    );
    await CustomMapStorageService.instance.loadAll();
  });

  testWidgets('Generate Hiragana Map in SettingsPage without layout overflow or disposal crash', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap 'Generate Random Map'
    final generateBtn = find.text('Generate Random Map');
    expect(generateBtn, findsOneWidget);
    await tester.tap(generateBtn);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Character / Word Pool'), findsOneWidget);

    // Tap dropdown
    final dropdownFinder = find.byType(DropdownButtonFormField<String>);
    expect(dropdownFinder, findsOneWidget);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Tap 'Hiragana Characters (58 chars)'
    final hiraganaItem = find.text('Hiragana Characters (58 chars)').last;
    await tester.tap(hiraganaItem);
    await tester.pumpAndSettle();

    // Tap 'Generate & Save'
    final saveBtn = find.text('Generate & Save');
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verify map was created and visible in list
    expect(CustomMapStorageService.instance.profiles.any((p) => p.name.contains('Hiragana')), isTrue);
    expect(find.text('Hiragana Chars Map 1'), findsOneWidget);
  });

  testWidgets('Import map via SettingsPage import dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap 'Import Map'
    final importBtn = find.text('Import Map');
    expect(importBtn, findsOneWidget);
    await tester.tap(importBtn);
    await tester.pumpAndSettle();

    expect(find.text('Import Custom Map'), findsOneWidget);

    // Generate valid sample map json
    final validMap = V2MapGenerator.generate('latin');
    final dummyProfile = CustomObfuscationProfile(name: 'Imported Latin Map', map: validMap);
    final validJson = CustomMapStorageService.instance.exportMap(dummyProfile);

    final textField = find.byType(TextField);
    await tester.enterText(textField, validJson);
    await tester.pumpAndSettle();

    final submitBtn = find.text('Import');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(CustomMapStorageService.instance.profiles.any((p) => p.name == 'Imported Latin Map'), isTrue);
  });

  testWidgets('CustomMapPickerDialog import dialog functions cleanly', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext ctx;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold(body: Text('Home'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    showCustomMapPickerDialog(ctx);
    await tester.pumpAndSettle();

    expect(find.text('Import New Map'), findsOneWidget);
    await tester.tap(find.text('Import New Map'));
    await tester.pumpAndSettle();

    expect(find.text('Import & Use'), findsOneWidget);

    final validMap = V2MapGenerator.generate('greek');
    final dummyProfile = CustomObfuscationProfile(name: 'Picker Imported Greek', map: validMap);
    final validJson = CustomMapStorageService.instance.exportMap(dummyProfile);

    final textField = find.byType(TextField);
    await tester.enterText(textField, validJson);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import & Use'));
    await tester.pumpAndSettle();

    expect(CustomMapStorageService.instance.profiles.any((p) => p.name == 'Picker Imported Greek'), isTrue);
  });
}
