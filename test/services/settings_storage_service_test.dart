import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/settings/settings_storage_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.initializeTags();
  });

  group('v2Equivalent extension', () {
    test('maps legacy methods to v2 and keeps other methods unchanged', () {
      expect(ObfuscationMethod.en1.v2Equivalent, ObfuscationMethod.en1v2);
      expect(ObfuscationMethod.en2.v2Equivalent, ObfuscationMethod.en2v2);
      expect(ObfuscationMethod.fa1.v2Equivalent, ObfuscationMethod.fa1v2);
      expect(ObfuscationMethod.fa2.v2Equivalent, ObfuscationMethod.fa2v2);

      expect(ObfuscationMethod.none.v2Equivalent, ObfuscationMethod.none);
      expect(ObfuscationMethod.b64.v2Equivalent, ObfuscationMethod.b64);
      expect(ObfuscationMethod.rot13.v2Equivalent, ObfuscationMethod.rot13);
      expect(ObfuscationMethod.xor.v2Equivalent, ObfuscationMethod.xor);
      expect(ObfuscationMethod.en1v2.v2Equivalent, ObfuscationMethod.en1v2);
      expect(ObfuscationMethod.en2v2.v2Equivalent, ObfuscationMethod.en2v2);
      expect(ObfuscationMethod.fa1v2.v2Equivalent, ObfuscationMethod.fa1v2);
      expect(ObfuscationMethod.fa2v2.v2Equivalent, ObfuscationMethod.fa2v2);
    });
  });

  group('SettingsStorageService.getDefaultObfuscationMethod', () {
    test('coerces stored legacy methods to v2 equivalents', () async {
      FlutterSecureStorage.setMockInitialValues({
        'default_obfuscation_method': 'en2',
      });
      expect(
        await SettingsStorageService.getDefaultObfuscationMethod(),
        ObfuscationMethod.en2v2,
      );

      FlutterSecureStorage.setMockInitialValues({
        'default_obfuscation_method': 'fa1',
      });
      expect(
        await SettingsStorageService.getDefaultObfuscationMethod(),
        ObfuscationMethod.fa1v2,
      );

      FlutterSecureStorage.setMockInitialValues({
        'default_obfuscation_method': 'en1',
      });
      expect(
        await SettingsStorageService.getDefaultObfuscationMethod(),
        ObfuscationMethod.en1v2,
      );

      FlutterSecureStorage.setMockInitialValues({
        'default_obfuscation_method': 'fa2',
      });
      expect(
        await SettingsStorageService.getDefaultObfuscationMethod(),
        ObfuscationMethod.fa2v2,
      );
    });

    test('preserves stored non-legacy methods', () async {
      FlutterSecureStorage.setMockInitialValues({
        'default_obfuscation_method': 'none',
      });
      expect(
        await SettingsStorageService.getDefaultObfuscationMethod(),
        ObfuscationMethod.none,
      );

      FlutterSecureStorage.setMockInitialValues({
        'default_obfuscation_method': 'en2v2',
      });
      expect(
        await SettingsStorageService.getDefaultObfuscationMethod(),
        ObfuscationMethod.en2v2,
      );
    });
  });
}
