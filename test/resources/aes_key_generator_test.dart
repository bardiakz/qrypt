import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/resources/global_resources.dart';

void main() {
  group('generateRandomAesKey', () {
    test('generates valid 32-character key by default', () {
      final key = generateRandomAesKey();
      expect(key.length, equals(32));
      expect(validateAesKey(key), isNull);
    });

    test('generates valid 16 and 24 character keys when requested', () {
      final key16 = generateRandomAesKey(length: 16);
      expect(key16.length, equals(16));
      expect(validateAesKey(key16), isNull);

      final key24 = generateRandomAesKey(length: 24);
      expect(key24.length, equals(24));
      expect(validateAesKey(key24), isNull);
    });

    test('all characters are drawn from the defined alphabet', () {
      const allowedChars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()';
      final allowedSet = allowedChars.runes.toSet();

      for (var i = 0; i < 50; i++) {
        final key = generateRandomAesKey();
        for (final rune in key.runes) {
          expect(allowedSet.contains(rune), isTrue);
        }
      }
    });

    test('generates distinct keys without keyspace collapse (not sliding window)', () {
      const chars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()';
      final doubleAlphabet = chars + chars;

      final generatedKeys = <String>{};
      const samples = 500;

      for (var i = 0; i < samples; i++) {
        final key = generateRandomAesKey();
        generatedKeys.add(key);

        // Verify key is not merely a 32-character consecutive substring of the alphabet
        expect(
          doubleAlphabet.contains(key),
          isFalse,
          reason:
              'Key should not be a trivial consecutive sliding-window substring',
        );
      }

      // With secure RNG over a 72-char alphabet and length 32, 500 keys must all be unique
      expect(generatedKeys.length, equals(samples));
    });
  });
}
