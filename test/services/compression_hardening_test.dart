import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:qrypt/models/Qrypt.dart';
import 'package:qrypt/models/compression_method.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/models/sign_method.dart';
import 'package:qrypt/services/aes_encryption.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/compression_io.dart' as compression_io;
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Compression.setNativeLibPaths();
    await Obfuscate.setAllMaps();
    TagManager.loadAllTags();
  });

  group('Compression & Decompression Hardening', () {
    test('exact uncompressed meta-block streams with trailing 0x03 byte decode cleanly', () {
      final sample14 = Uint8List.fromList(
        [139, 4, 128, 104, 101, 105, 32, 102, 105, 120, 101, 100, 63, 3],
      );
      expect(utf8.decode(Compression.brotliDeCompress(sample14)), 'hei fixed?');

      final sample15 = Uint8List.fromList(
        [11, 5, 128, 98, 114, 111, 116, 108, 105, 32, 116, 101, 115, 116, 3],
      );
      expect(utf8.decode(Compression.brotliDeCompress(sample15)), 'brotli test');
    });

    test('truncated brotli data throws FormatException', () {
      final validData = [
        139,
        6,
        0,
        248,
        165,
        202,
        220,
        82,
        16,
        66,
        36,
        169,
        78,
        214,
        137,
        98,
        214,
        0,
        3,
      ];
      expect(
        utf8.decode(Compression.brotliDeCompress(validData)),
        'legacy test en',
      );

      final truncated = validData.sublist(0, 18);
      expect(
        () => Compression.brotliDeCompress(truncated),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'empty input to decompression methods returns empty list without crashing',
      () {
        expect(Compression.brotliDeCompress([]), isEmpty);
        expect(Compression.gZipDeCompress([]), isEmpty);
        expect(Compression.lz4DeCompress([]), isEmpty);
        expect(Compression.zstdDeCompress([]), isEmpty);
      },
    );

    test(
      'InputHandler handleDeCompression throws FormatException on corrupted data',
      () {
        final ih = InputHandler();
        final q = Qrypt(
          text: '',
          encryption: EncryptionMethod.none,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.brotli,
          sign: SignMethod.none,
        );
        q.deCompressedText = [1, 2, 3, 4, 5]; // Corrupted bytes

        expect(
          () => ih.handleDeCompression(q),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'full round-trip encryption, obfuscation, deobfuscation, decryption, and decompression succeeds',
      () async {
        final ih = InputHandler();
        const testKey = 'TestKeyForCompression0123456789_';
        final qEncrypt = Qrypt.withTag(
          text: 'test brotli pipeline message',
          encryption: EncryptionMethod.aesGcm,
          obfuscation: ObfuscationMethod.en2,
          compression: CompressionMethod.brotli,
          sign: SignMethod.none,
          useTag: true,
        );
        qEncrypt.customKey = testKey;
        qEncrypt.useCustomKey = true;

        final processed = await ih.handleProcess(qEncrypt);
        expect(processed.text, isNotEmpty);

        // Decrypt
        final qDecrypt = Qrypt.autoDecrypt(text: processed.text);
        final matchedTag = TagManager.matchedTag(qDecrypt.text);
        expect(matchedTag, isNotNull);
        qDecrypt.text = qDecrypt.text.substring(matchedTag!.length);
        final methods = TagManager.getMethodsFromTag(matchedTag);
        qDecrypt.obfuscation = methods!.obfuscation;
        qDecrypt.encryption = methods.encryption;
        qDecrypt.compression = methods.compression;
        qDecrypt.sign = methods.sign;

        final deobf = ih.handleDeObfs(qDecrypt);
        final parts = InputHandler.parseByColon(deobf.text);
        expect(parts.length, 2);

        final key = encrypt.Key.fromUtf8(testKey);
        final decrypted = Aes.decryptAesGcm(parts[0], parts[1], key);
        expect(decrypted, isNotNull);
        qDecrypt.deCompressedText = decrypted!;
        final result = ih.handleDeCompression(qDecrypt);
        expect(result.text, 'test brotli pipeline message');
      },
    );

    group('BoundedByteSink Unit Tests', () {
      test('accumulates bytes via add and addSlice within bounds', () {
        final sink = BoundedByteSink(maxBytes: 100);
        sink.add([1, 2, 3]);
        sink.addSlice([10, 20, 30, 40], 1, 3, false); // adds [20, 30]
        final uint8Data = Uint8List.fromList([100, 101, 102, 103]);
        sink.addSlice(uint8Data, 0, 2, true); // adds [100, 101]
        final bytes = sink.takeBytes();
        expect(bytes, equals([1, 2, 3, 20, 30, 100, 101]));
      });

      test('validates slice ranges and throws RangeError', () {
        final sink = BoundedByteSink(maxBytes: 100);
        expect(
          () => sink.addSlice([1, 2, 3], 0, 5, false),
          throwsA(isA<RangeError>()),
        );
      });

      test('throws DecompressionBombException immediately when limit exceeded', () {
        final sink = BoundedByteSink(maxBytes: 10);
        sink.add([1, 2, 3, 4, 5]);
        expect(
          () => sink.add([6, 7, 8, 9, 10, 11]),
          throwsA(isA<DecompressionBombException>()),
        );
      });
    });

    group('Bounded Decompression Bomb Guards', () {
      test('all codecs abort and throw DecompressionBombException on oversized stream', () {
        final payload = Uint8List(50 * 1024); // 50 KB of repeating data
        for (int i = 0; i < payload.length; i++) {
          payload[i] = i % 256;
        }

        final gz = Compression.gZipCompress(payload);
        final br = Compression.brotliCompress(payload);
        final lz = Compression.lz4Compress(payload);
        final zs = Compression.zstdCompress(payload);

        const limit = 1024; // 1 KB bound
        expect(
          () => Compression.gZipDeCompress(gz, maxBytes: limit),
          throwsA(isA<DecompressionBombException>()),
        );
        expect(
          () => Compression.brotliDeCompress(br, maxBytes: limit),
          throwsA(isA<DecompressionBombException>()),
        );
        expect(
          () => Compression.lz4DeCompress(lz, maxBytes: limit),
          throwsA(isA<DecompressionBombException>()),
        );
        expect(
          () => Compression.zstdDeCompress(zs, maxBytes: limit),
          throwsA(isA<DecompressionBombException>()),
        );
      });

      test('handleDeCompression throws FormatException with clear limit message', () {
        final ih = InputHandler();
        // Fast compression of 26 MB zero-bytes with LZ4 (<50ms) to trigger default 25 MB cap
        final bigPayload = Uint8List(26 * 1024 * 1024);
        final compressed = Compression.lz4Compress(bigPayload);

        final q = Qrypt(
          text: '',
          encryption: EncryptionMethod.none,
          obfuscation: ObfuscationMethod.none,
          compression: CompressionMethod.lZ4,
          sign: SignMethod.none,
        );
        q.deCompressedText = compressed;

        expect(
          () => ih.handleDeCompression(q),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Decompression aborted: Payload exceeds safety limit of 25 MB.'),
            ),
          ),
        );
      });
    });

    group('Truncation Parity & Codec Integrity Gap', () {
      // NOTE: GZip, LZ4, and Zstd currently return partial decompressed data without throwing on truncated input.
      // This is a documented pre-existing integrity limitation of the underlying archive and es_compression packages.
      // Brotli is the only codec that actively throws FormatException on truncation.
      // This test enforces regression parity between the bounded streaming path and existing behavior.
      test('Brotli throws FormatException while GZip, LZ4, and Zstd emit partial data on truncation', () {
        final original = Uint8List.fromList(List.generate(500, (i) => i % 256));

        final gz = Compression.gZipCompress(original);
        final br = Compression.brotliCompress(original);
        final lz = Compression.lz4Compress(original);
        final zs = Compression.zstdCompress(original);

        // Truncate to half length
        final gzTrunc = gz.sublist(0, gz.length ~/ 2);
        final brTrunc = br.sublist(0, br.length ~/ 2);
        final lzTrunc = lz.sublist(0, lz.length ~/ 2);
        final zsTrunc = zs.sublist(0, zs.length ~/ 2);

        // Brotli throws FormatException
        expect(
          () => Compression.brotliDeCompress(brTrunc),
          throwsA(isA<FormatException>()),
        );

        // GZip, LZ4, and Zstd return partial data (or empty) without throwing (pre-existing codec behavior)
        final gzOut = Compression.gZipDeCompress(gzTrunc);
        expect(gzOut, isNotEmpty);
        expect(gzOut.length, lessThan(original.length));

        final lzOut = Compression.lz4DeCompress(lzTrunc);
        expect(lzOut.length, lessThan(original.length));

        final zsOut = Compression.zstdDeCompress(zsTrunc);
        expect(zsOut.length, lessThan(original.length));
      });
    });

    group('Native Library Path Resolution', () {
      const expectedLinuxLibs = [
        'eslz4-linux64.so',
        'esbrotli-linux64.so',
        'eszstd-linux64.so',
      ];

      void createDummyLibs(String dir, List<String> libs) {
        Directory(dir).createSync(recursive: true);
        for (final lib in libs) {
          File(path.join(dir, lib)).writeAsBytesSync(const []);
        }
      }

      test('prefers execDir/lib over bundled flutter_assets/native_libs', () {
        final root = Directory.systemTemp.createTempSync('qrypt_native_lib_');
        addTearDown(() => root.deleteSync(recursive: true));

        final libDir = path.join(root.path, 'lib');
        final assetsDir = path.join(root.path, 'data', 'flutter_assets', 'native_libs');
        createDummyLibs(libDir, expectedLinuxLibs);
        createDummyLibs(assetsDir, expectedLinuxLibs);

        final resolved = compression_io.Compression.resolveNativeLibBasePath(
          execDir: root.path,
          expectedLibs: expectedLinuxLibs,
        );
        expect(resolved, libDir);
      });

      test('falls back to flutter_assets/native_libs when lib lacks codecs', () {
        final root = Directory.systemTemp.createTempSync('qrypt_native_lib_');
        addTearDown(() => root.deleteSync(recursive: true));

        final libDir = path.join(root.path, 'lib');
        Directory(libDir).createSync(recursive: true);
        File(path.join(libDir, 'liboqs.so')).writeAsBytesSync(const []);

        final assetsDir = path.join(root.path, 'data', 'flutter_assets', 'native_libs');
        createDummyLibs(assetsDir, expectedLinuxLibs);

        final resolved = compression_io.Compression.resolveNativeLibBasePath(
          execDir: root.path,
          expectedLibs: expectedLinuxLibs,
        );
        expect(resolved, assetsDir);
      });

      test('prefers linux-arm64 subdir over generic native_libs when isLinuxArm64 is true', () {
        final root = Directory.systemTemp.createTempSync('qrypt_native_lib_');
        addTearDown(() => root.deleteSync(recursive: true));

        final assetsDir = path.join(root.path, 'data', 'flutter_assets', 'native_libs');
        final armAssetsDir = path.join(assetsDir, 'linux-arm64');
        createDummyLibs(assetsDir, expectedLinuxLibs);
        createDummyLibs(armAssetsDir, expectedLinuxLibs);

        final resolved = compression_io.Compression.resolveNativeLibBasePath(
          execDir: root.path,
          expectedLibs: expectedLinuxLibs,
          isLinuxArm64: true,
        );
        expect(resolved, armAssetsDir);
      });
    });
  });
}
