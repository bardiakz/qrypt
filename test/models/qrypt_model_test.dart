import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/rsa_key_pair.dart';
import 'package:qrypt/models/sign_method.dart';

void main() {
  group('Qrypt model safety & modern standards', () {
    test('autoDecrypt initializes safe defaults without LateInitializationError', () {
      final q = Qrypt.autoDecrypt(text: 'samplePayload');

      // Accessing methods/fields should never throw LateInitializationError
      expect(q.encryption, equals(EncryptionMethod.none));
      expect(q.obfuscation, equals(ObfuscationMethod.none));
      expect(q.compression, equals(CompressionMethod.none));
      expect(q.sign, equals(SignMethod.none));
      expect(q.getEncryptionMethod(), equals(EncryptionMethod.none));
      expect(q.getObfuscationMethod(), equals(ObfuscationMethod.none));
      expect(q.getCompressionMethod(), equals(CompressionMethod.none));
      expect(q.getSignMethod(), equals(SignMethod.none));
      expect(q.useTag, isTrue);
      expect(q.compressedText, isEmpty);
      expect(q.deCompressedText, isEmpty);
    });

    test('RSAKeyPair.empty is reusable and has valid empty structure', () {
      final empty1 = RSAKeyPair.empty;
      final empty2 = RSAKeyPair.empty;

      expect(identical(empty1, empty2), isTrue);
      expect(empty1.id, isEmpty);
      expect(empty1.name, isEmpty);
      expect(empty1.publicKey, isEmpty);
      expect(empty1.privateKey, isEmpty);

      final q = Qrypt.autoDecrypt(text: 'sample');
      expect(q.rsaKeyPair.publicKey, isEmpty);
    });

    test('dsaVerifyPublicKey and deprecated dsaVerifyPublicKEy alias are synchronized', () {
      final q = Qrypt.autoDecrypt(text: 'test');
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      // Setting via new field updates deprecated alias
      q.dsaVerifyPublicKey = dummyBytes;
      // ignore: deprecated_member_use_from_same_package
      expect(q.dsaVerifyPublicKEy, equals(dummyBytes));

      // Setting via deprecated alias updates new field
      final updatedBytes = Uint8List.fromList([5, 6, 7]);
      // ignore: deprecated_member_use_from_same_package
      q.dsaVerifyPublicKEy = updatedBytes;
      expect(q.dsaVerifyPublicKey, equals(updatedBytes));
    });

    test('toString returns readable debug string with method names and tag', () {
      final q = Qrypt(
        text: 'Hello',
        encryption: EncryptionMethod.aesGcm,
        obfuscation: ObfuscationMethod.b64,
        compression: CompressionMethod.gZip,
        sign: SignMethod.rsaPss,
      );
      q.tag = 'abc123';

      expect(
        q.toString(),
        equals('Qrypt(enc: aesGcm, comp: gZip, sign: rsaPss, obf: b64, tag: abc123)'),
      );
    });

    test('withKem forces compression to none and sets encryption to mlKem', () {
      final q = Qrypt.withKem(
        text: 'payload',
        obfuscation: ObfuscationMethod.none,
        useTag: false,
        kemReceiverPublicKey: 'dummyPub',
        sign: SignMethod.none,
      );

      expect(q.encryption, equals(EncryptionMethod.mlKem));
      expect(q.compression, equals(CompressionMethod.none));
    });
  });
}
