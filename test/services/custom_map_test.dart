import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/custom_obfuscation_profile.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/resources/obfuscation/v2_map_pools.dart';
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/obfuscation/custom_map_storage_service.dart';
import 'package:qrypt/services/obfuscation/obfuscation_service.dart';
import 'package:qrypt/services/obfuscation/v2_map_generator.dart';
import 'package:qrypt/services/settings/settings_storage_service.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Obfuscate.setAllMaps();
    TagManager.loadAllTags();
    await CustomMapStorageService.instance.initialize();
  });

  tearDown(() async {
    // Clean up any saved profiles after each test
    for (final p in List.of(CustomMapStorageService.instance.profiles)) {
      await CustomMapStorageService.instance.deleteMap(p.id);
    }
  });

  group('840 Built-in Tags Invariant', () {
    test('built-in tags remain exactly 840 and are untouched by custom', () {
      expect(TagManager.knownTags.length, equals(840));
    });
  });

  group('V2MapGenerator & Map Validation', () {
    test('V2MapGenerator generates strictly valid v2 maps from each pool', () {
      final poolKeys = [
        'en-words',
        'fa-words',
        'latin',
        'persian',
        'cyrillic',
        'greek',
        'hebrew',
      ];

      for (final poolKey in poolKeys) {
        final map = V2MapGenerator.generate(poolKey);
        expect(map.length, equals(17));
        final problems = ObfuscationService.validateV2Map(map);
        expect(problems, isEmpty, reason: 'Failed validation for pool $poolKey');
      }
    });

    test('validateV2Map catches missing keys', () {
      final map = V2MapGenerator.generate('latin');
      map.remove(':');
      final problems = ObfuscationService.validateV2Map(map);
      expect(problems, isNotEmpty);
      expect(
        problems.any((p) =>
            p.toLowerCase().contains('missing') ||
            p.toLowerCase().contains('domain') ||
            p.contains(':')),
        isTrue,
      );
    });

    test('validateV2Map catches extra keys', () {
      final map = V2MapGenerator.generate('latin');
      map['x'] = 'z';
      final problems = ObfuscationService.validateV2Map(map);
      expect(problems, isNotEmpty);
      expect(problems.any((p) => p.contains('Unexpected key "x"')), isTrue);
    });

    test('validateV2Map catches non-prefix-free mappings in word/token maps', () {
      final map = V2MapGenerator.generate('en-words');
      map['0'] = 'apple';
      map['1'] = 'applesauce'; // 'apple' is a prefix of 'applesauce'
      final problems = ObfuscationService.validateV2Map(map);
      expect(problems, isNotEmpty);
      expect(problems.any((p) => p.contains('Not prefix-free')), isTrue);
    });

    test('validateV2Map catches unvetted characters outside pools', () {
      final map = V2MapGenerator.generate('latin');
      map['0'] = '🔥'; // Emoji not in vetted pool
      final problems = ObfuscationService.validateV2Map(map);
      expect(problems, isNotEmpty);
      expect(problems.any((p) => p.contains('which is not in the vetted letter pools')), isTrue);
    });
  });

  group('Custom Profile Serialization & Share Format', () {
    test('share format matches specification {"v":1,"n":name,"m":[17 values]}', () {
      final map = V2MapGenerator.generate('latin');
      final profile = CustomObfuscationProfile(
        id: 'test-id',
        name: '  Alpha Map \n with \t spaces   ',
        map: map,
        createdAt: DateTime.now(),
      );

      final shareMap = profile.toShareJson();
      expect(shareMap['v'], equals(1));
      expect(shareMap['n'], equals('Alpha Map with spaces')); // sanitized name
      expect(shareMap['m'], isA<List>());
      expect((shareMap['m'] as List).length, equals(17));

      // Import back
      final imported = CustomObfuscationProfile.fromShareJson(shareMap);
      expect(imported.name, equals('Alpha Map with spaces'));
      expect(imported.map, equals(map));
    });

    test('export and import json string roundtrip', () async {
      final map = V2MapGenerator.generate('latin');
      final profile = CustomObfuscationProfile(
        id: 'test-id-2',
        name: 'Exported Map',
        map: map,
        createdAt: DateTime.now(),
      );

      final jsonStr = CustomMapStorageService.instance.exportMap(profile);
      expect(jsonStr, contains('"v": 1'));
      expect(jsonStr, contains('"n": "Exported Map"'));
      expect(jsonStr, contains('"m":'));

      final imported = await CustomMapStorageService.instance.importMap(jsonStr);
      expect(imported.name, equals('Exported Map'));
      expect(imported.map, equals(map));
    });

    test('fromShareJson rejects malformed json or incorrect lengths', () {
      // Invalid version
      expect(
        () => CustomObfuscationProfile.fromShareJson({'v': 2, 'n': 'test', 'm': []}),
        throwsFormatException,
      );

      // Not 17 elements
      expect(
        () => CustomObfuscationProfile.fromShareJson({'v': 1, 'n': 'test', 'm': ['a', 'b']}),
        throwsFormatException,
      );

      // Invalid JSON string in importMap
      expect(
        () => CustomMapStorageService.instance.importMap('not a json'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Custom Tag Index & Matching (Option 1A)', () {
    test('custom tag matching identifies profile and crypto methods', () async {
      final map = V2MapGenerator.generate('latin');
      final profile = await CustomMapStorageService.instance.saveMap(
        name: 'TagTest1',
        map: map,
      );

      // Create a Qrypt with custom obfuscation
      final q = Qrypt(
        text: 'Secret payload content',
        compression: CompressionMethod.gZip,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.custom,
        sign: SignMethod.none,
        customMap: profile.map,
      );

      TagManager.setTag(q);
      expect(q.tag, isNotNull);

      // Obfuscate tag using profile's codec
      final codec = ObfuscationService.buildV2Codec(profile.map);
      final obfsTag = codec.encode(q.tag!);

      final fullMessage = '$obfsTag:other_message_data';
      final match = TagManager.matchedCustomTag(fullMessage);

      expect(match, isNotNull);
      expect(match!.match.profile.id, equals(profile.id));
      expect(match.match.methods.compression, equals(CompressionMethod.gZip));
      expect(match.match.methods.encryption, equals(EncryptionMethod.aesGcm));
      expect(match.match.methods.sign, equals(SignMethod.none));
    });

    test('no match for unknown tags or built-in tags', () {
      final builtInTag = TagManager.knownTags.first;
      expect(TagManager.matchedCustomTag('$builtInTag:payload'), isNull);
      expect(TagManager.matchedCustomTag('completely_random_string'), isNull);
      expect(TagManager.matchedCustomTag(''), isNull);
    });

    test('distinguishes between two different custom profiles', () async {
      final map1 = V2MapGenerator.generate('latin');
      final map2 = V2MapGenerator.generate('cyrillic');

      final profile1 = await CustomMapStorageService.instance.saveMap(
        name: 'Profile1',
        map: map1,
      );
      final profile2 = await CustomMapStorageService.instance.saveMap(
        name: 'Profile2',
        map: map2,
      );

      final q1 = Qrypt(
        text: 'p1',
        compression: CompressionMethod.none,
        encryption: EncryptionMethod.none,
        obfuscation: ObfuscationMethod.custom,
        sign: SignMethod.none,
        customMap: profile1.map,
      );
      TagManager.setTag(q1);
      final tag1 = ObfuscationService.buildV2Codec(profile1.map).encode(q1.tag!);

      final q2 = Qrypt(
        text: 'p2',
        compression: CompressionMethod.none,
        encryption: EncryptionMethod.none,
        obfuscation: ObfuscationMethod.custom,
        sign: SignMethod.none,
        customMap: profile2.map,
      );
      TagManager.setTag(q2);
      final tag2 = ObfuscationService.buildV2Codec(profile2.map).encode(q2.tag!);

      final match1 = TagManager.matchedCustomTag('$tag1:body');
      final match2 = TagManager.matchedCustomTag('$tag2:body');

      expect(match1, isNotNull);
      expect(match1!.match.profile.id, equals(profile1.id));

      expect(match2, isNotNull);
      expect(match2!.match.profile.id, equals(profile2.id));
    });

    test('deleting a profile removes its tags from index', () async {
      final map = V2MapGenerator.generate('latin');
      final profile = await CustomMapStorageService.instance.saveMap(
        name: 'To Delete',
        map: map,
      );

      final q = Qrypt(
        text: 'test',
        compression: CompressionMethod.gZip,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.custom,
        sign: SignMethod.none,
        customMap: profile.map,
      );
      TagManager.setTag(q);
      final tag = ObfuscationService.buildV2Codec(profile.map).encode(q.tag!);

      expect(TagManager.matchedCustomTag('$tag:body'), isNotNull);

      // Delete map
      await CustomMapStorageService.instance.deleteMap(profile.id);

      expect(TagManager.matchedCustomTag('$tag:body'), isNull);
    });

    test('checkCustomMapCollisions pre-flights map against built-in and custom tags', () {
      final map = V2MapGenerator.generate('latin');
      final collision = TagManager.checkCustomMapCollisions(map);
      // Fresh random map should not collide with built-in tags
      expect(collision, isNull);
    });

    test('saving duplicate map content is rejected', () async {
      final map = V2MapGenerator.generate('latin');
      await CustomMapStorageService.instance.saveMap(
        name: 'First Save',
        map: map,
      );

      expect(
        () => CustomMapStorageService.instance.saveMap(
          name: 'Duplicate Map',
          map: map,
        ),
        throwsStateError,
      );
    });
  });

  group('Import / Export Bundle Operations', () {
    test('single and multi map import and export', () async {
      final map1 = V2MapGenerator.generate('latin');
      final map2 = V2MapGenerator.generate('greek');

      final p1 = await CustomMapStorageService.instance.saveMap(name: 'Map 1', map: map1);
      final p2 = await CustomMapStorageService.instance.saveMap(name: 'Map 2', map: map2);

      final exportedBundle = await CustomMapStorageService.instance.exportAllMaps();
      final bundleJson = jsonDecode(exportedBundle) as Map<String, dynamic>;
      expect(bundleJson['v'], equals(1));
      expect((bundleJson['maps'] as List).length, equals(2));

      // Clear storage
      await CustomMapStorageService.instance.deleteMap(p1.id);
      await CustomMapStorageService.instance.deleteMap(p2.id);
      expect(CustomMapStorageService.instance.profiles, isEmpty);

      // Import bundle back
      final imported = await CustomMapStorageService.instance.importAllMaps(exportedBundle);
      expect(imported.length, equals(2));
      expect(CustomMapStorageService.instance.profiles.length, equals(2));
    });

    test('import rejects invalid map validation rules', () async {
      final invalidMapJson = jsonEncode({
        'v': 1,
        'n': 'Invalid Map',
        'm': [
          'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
          'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
          'not_prefix_free_pp', // unvetted and invalid
        ],
      });

      expect(
        () => CustomMapStorageService.instance.importMap(invalidMapJson),
        throwsFormatException,
      );
    });
  });

  group('Settings & Presets Safety', () {
    test('default method fallback never produces custom', () async {
      // Even if settings storage had 'custom' saved
      await SettingsStorageService.setDefaultObfuscationMethod(ObfuscationMethod.custom);
      final resolved = await SettingsStorageService.getDefaultObfuscationMethod();
      expect(resolved, isNot(equals(ObfuscationMethod.custom)));
      expect(resolved, equals(ObfuscationService.defaultMethod));
    });

    test('ObfuscationService._codec(custom) throws ArgumentError', () {
      expect(
        () => ObfuscationService.obfuscate(ObfuscationMethod.custom, 'abc'),
        throwsArgumentError,
      );
      expect(
        () => ObfuscationService.deobfuscate(ObfuscationMethod.custom, 'abc'),
        throwsArgumentError,
      );
    });
  });

  group('Full Pipeline Encryption & Decryption Roundtrip with Custom Map', () {
    const testAesKey = '0123456789abcdef0123456789abcdef';

    test('encrypts and auto-decrypts with custom map via tag matching', () async {
      final map = V2MapGenerator.generate('en-words');
      final profile = await CustomMapStorageService.instance.saveMap(
        name: 'PipelineMap',
        map: map,
      );

      final qrypt = Qrypt(
        text: 'The quick brown fox jumps over the lazy dog',
        compression: CompressionMethod.gZip,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.custom,
        sign: SignMethod.none,
        customMap: profile.map,
      );
      qrypt.customKey = testAesKey;
      qrypt.useCustomKey = true;

      // Set tag and process (encrypt)
      TagManager.setTag(qrypt);
      final encryptedQrypt = await InputHandler().handleProcess(qrypt);

      expect(encryptedQrypt.text, isNotEmpty);
      expect(encryptedQrypt.text, isNot(contains('The quick brown fox')));

      // Auto-detect & decrypt
      final decryptTarget = Qrypt.autoDecrypt(text: encryptedQrypt.text);
      decryptTarget.customKey = testAesKey;
      decryptTarget.useCustomKey = true;

      final decryptedQrypt = await InputHandler().handleDeProcess(
        null,
        decryptTarget,
        true,
      );

      expect(decryptedQrypt.text, equals('The quick brown fox jumps over the lazy dog'));
      expect(decryptedQrypt.obfuscation, equals(ObfuscationMethod.custom));
    });

    test('manual decrypt with custom map when tag is not used', () async {
      final map = V2MapGenerator.generate('latin');
      final profile = await CustomMapStorageService.instance.saveMap(
        name: 'ManualMap',
        map: map,
      );

      final qrypt = Qrypt(
        text: 'Confidential Payload Without Tag',
        compression: CompressionMethod.none,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.custom,
        sign: SignMethod.none,
        customMap: profile.map,
      );
      qrypt.customKey = testAesKey;
      qrypt.useCustomKey = true;

      // Process without tag (tag = '')
      qrypt.tag = '';
      final encryptedQrypt = await InputHandler().handleProcess(qrypt);

      // Manually decrypt specifying methods and custom map
      final decryptTarget = Qrypt(
        text: encryptedQrypt.text,
        compression: CompressionMethod.none,
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.custom,
        sign: SignMethod.none,
        customMap: profile.map,
      );
      decryptTarget.customKey = testAesKey;
      decryptTarget.useCustomKey = true;

      final decryptedQrypt = await InputHandler().handleDeProcess(
        null,
        decryptTarget,
        false,
      );

      expect(decryptedQrypt.text, equals('Confidential Payload Without Tag'));
    });
  });
}
