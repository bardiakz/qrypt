import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/aes_key.dart';
import 'package:qrypt/resources/global_resources.dart';
import 'package:qrypt/services/aes/aes_key_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AESKey Model', () {
    test('serializes to and from JSON correctly', () {
      final now = DateTime.now();
      final key = AESKey(
        id: 'test-id-123',
        name: 'My Personal Key',
        key: 'abcdefghijklmnopqrstuvwxyz012345',
        createdAt: now,
      );

      final json = key.toJson();
      expect(json['id'], equals('test-id-123'));
      expect(json['name'], equals('My Personal Key'));
      expect(json['key'], equals('abcdefghijklmnopqrstuvwxyz012345'));
      expect(json['createdAt'], equals(now.toIso8601String()));

      final reconstructed = AESKey.fromJson(json);
      expect(reconstructed, equals(key));
      expect(reconstructed.id, equals(key.id));
      expect(reconstructed.name, equals(key.name));
      expect(reconstructed.key, equals(key.key));
      expect(
        reconstructed.createdAt.toIso8601String(),
        equals(now.toIso8601String()),
      );
    });

    test('equality and hashCode are based on id', () {
      final now = DateTime.now();
      final key1 = AESKey(
        id: 'same-id',
        name: 'Name 1',
        key: 'key1',
        createdAt: now,
      );
      final key2 = AESKey(
        id: 'same-id',
        name: 'Name 2',
        key: 'key2',
        createdAt: now,
      );
      final key3 = AESKey(
        id: 'different-id',
        name: 'Name 1',
        key: 'key1',
        createdAt: now,
      );

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
      expect(key1, isNot(equals(key3)));
    });

    test('calculates byteLength and bitLength accurately', () {
      final key = AESKey(
        id: 'k-1',
        name: 'Key',
        key: '12345678901234567890123456789012',
        createdAt: DateTime.now(),
      );
      expect(key.byteLength, equals(32));
      expect(key.bitLength, equals(256));
    });

    test('toString redacts the secret key', () {
      final key = AESKey(
        id: 'safe-id',
        name: 'SafeKey',
        key: 'super-secret-key-12345678901234',
        createdAt: DateTime.now(),
      );
      final str = key.toString();
      expect(str.contains('safe-id'), isTrue);
      expect(str.contains('SafeKey'), isTrue);
      expect(str.contains('super-secret-key'), isFalse);
    });

    test('copyWith updates specified fields', () {
      final now = DateTime.now();
      final original = AESKey(
        id: 'id-1',
        name: 'Original',
        key: 'orig-key',
        createdAt: now,
      );

      final updated = original.copyWith(name: 'Updated');
      expect(updated.id, equals('id-1'));
      expect(updated.name, equals('Updated'));
      expect(updated.key, equals('orig-key'));
    });
  });

  group('AesKeyStorageService', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('returns empty list when no keys stored', () async {
      const service = AesKeyStorageService();
      final keys = await service.getKeys();
      expect(keys, isEmpty);
    });

    test('saves and retrieves an AES key', () async {
      const service = AesKeyStorageService();
      final key = AESKey(
        id: 'uuid-1',
        name: 'Work Key',
        key: '01234567890123456789012345678901',
        createdAt: DateTime.now(),
      );

      await service.saveKey(key);
      final retrieved = await service.getKeys();

      expect(retrieved.length, equals(1));
      expect(retrieved.first.id, equals('uuid-1'));
      expect(retrieved.first.name, equals('Work Key'));
      expect(retrieved.first.key, equals('01234567890123456789012345678901'));
    });

    test('getKeyById returns correct key or null if not found', () async {
      const service = AesKeyStorageService();
      final key1 = AESKey(
        id: 'uuid-1',
        name: 'Key 1',
        key: '11111111111111111111111111111111',
        createdAt: DateTime.now(),
      );
      final key2 = AESKey(
        id: 'uuid-2',
        name: 'Key 2',
        key: '22222222222222222222222222222222',
        createdAt: DateTime.now(),
      );

      await service.saveKey(key1);
      await service.saveKey(key2);

      final found = await service.getKeyById('uuid-2');
      expect(found, isNotNull);
      expect(found!.name, equals('Key 2'));

      final notFound = await service.getKeyById('uuid-non-existent');
      expect(notFound, isNull);
    });

    test('updates existing key with same id', () async {
      const service = AesKeyStorageService();
      final key = AESKey(
        id: 'uuid-1',
        name: 'Old Name',
        key: '11111111111111111111111111111111',
        createdAt: DateTime.now(),
      );
      await service.saveKey(key);

      final updatedKey = key.copyWith(name: 'New Name');
      await service.updateKey(updatedKey);

      final keys = await service.getKeys();
      expect(keys.length, equals(1));
      expect(keys.first.name, equals('New Name'));
    });

    test('deletes key by id', () async {
      const service = AesKeyStorageService();
      final key1 = AESKey(
        id: 'uuid-1',
        name: 'Key 1',
        key: '11111111111111111111111111111111',
        createdAt: DateTime.now(),
      );
      final key2 = AESKey(
        id: 'uuid-2',
        name: 'Key 2',
        key: '22222222222222222222222222222222',
        createdAt: DateTime.now(),
      );

      await service.saveKey(key1);
      await service.saveKey(key2);

      await service.deleteKey('uuid-1');

      final remaining = await service.getKeys();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('uuid-2'));
    });

    test('clears all keys', () async {
      const service = AesKeyStorageService();
      final key = AESKey(
        id: 'uuid-1',
        name: 'Key',
        key: '11111111111111111111111111111111',
        createdAt: DateTime.now(),
      );
      await service.saveKey(key);
      expect((await service.getKeys()).length, equals(1));

      await service.clearAllKeys();
      expect((await service.getKeys()), isEmpty);
    });

    test('createRandomKey generates a valid 32-character AESKey', () {
      const service = AesKeyStorageService();
      final key = service.createRandomKey(name: 'Generated Key', length: 32);

      expect(key.id, isNotEmpty);
      expect(key.name, equals('Generated Key'));
      expect(key.key.length, equals(32));
      expect(validateAesKey(key.key), isNull);
    });
  });

  group('AES Key Validation', () {
    test('validates 16, 24, and 32 byte keys as valid', () {
      expect(validateAesKey('1234567890123456'), isNull);
      expect(validateAesKey('123456789012345678901234'), isNull);
      expect(validateAesKey('12345678901234567890123456789012'), isNull);
    });

    test('rejects keys of invalid lengths', () {
      expect(validateAesKey('short'), isNotNull);
      expect(validateAesKey('12345678901234567'), isNotNull); // 17 chars
      expect(
        validateAesKey('1234567890123456789012345'),
        isNotNull,
      ); // 25 chars
    });

    test('validates multibyte UTF-8 strings by byte count, not code units', () {
      // '123456789012345é' has 16 characters (code units), but 17 UTF-8 bytes
      expect(validateAesKey('123456789012345é'), isNotNull);
    });

    test('returns null for empty string (not active error)', () {
      expect(validateAesKey(''), isNull);
    });
  });
}
