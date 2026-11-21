import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:es_compression/lz4.dart';
import 'package:es_compression/brotli.dart';
import 'package:es_compression/zstd.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class Compression {
  /// Default expansion ceiling for clipboard/text-fed payloads (25 MB).
  static const int defaultMaxDecompressedBytes = 25 * 1024 * 1024;

  ///Compresses data using GZip
  static Uint8List gZipCompress(List<int> data) {
    final encoder = GZipEncoder();
    return Uint8List.fromList(encoder.encode(data));
  }

  ///Decompresses data using GZip with streaming expansion limits
  static List<int> gZipDeCompress(
    List<int> compressedData, {
    int maxBytes = defaultMaxDecompressedBytes,
  }) {
    if (compressedData.isEmpty) return <int>[];
    return _decodeBounded(gzip.decoder, compressedData, maxBytes: maxBytes);
  }

  static Uint8List lz4Compress(List<int> data) {
    final encoder = Lz4Codec(level: 16);
    return Uint8List.fromList(encoder.encode(data));
  }

  static List<int> lz4DeCompress(
    List<int> compressedData, {
    int maxBytes = defaultMaxDecompressedBytes,
  }) {
    if (compressedData.isEmpty) return <int>[];
    return _decodeBounded(Lz4Codec().decoder, compressedData, maxBytes: maxBytes);
  }

  static Uint8List brotliCompress(List<int> data) {
    final encoder = BrotliCodec(level: 11);
    return Uint8List.fromList(encoder.encode(data));
  }

  static List<int> brotliDeCompress(
    List<int> compressedData, {
    int maxBytes = defaultMaxDecompressedBytes,
  }) {
    if (compressedData.isEmpty) return <int>[];
    return _decodeBounded(BrotliCodec().decoder, compressedData, maxBytes: maxBytes);
  }

  static Uint8List zstdCompress(List<int> data) {
    final encoder = ZstdCodec(level: 22);
    return Uint8List.fromList(encoder.encode(data));
  }

  static List<int> zstdDeCompress(
    List<int> compressedData, {
    int maxBytes = defaultMaxDecompressedBytes,
  }) {
    if (compressedData.isEmpty) return <int>[];
    return _decodeBounded(ZstdCodec().decoder, compressedData, maxBytes: maxBytes);
  }

  static Uint8List _decodeBounded(
    Converter<List<int>, List<int>> decoder,
    List<int> data, {
    required int maxBytes,
  }) {
    final boundedSink = BoundedByteSink(maxBytes: maxBytes);
    final conversionSink = decoder.startChunkedConversion(boundedSink);
    bool isClosed = false;
    try {
      if (conversionSink is ByteConversionSink) {
        conversionSink.addSlice(data, 0, data.length, true);
        isClosed = true;
      } else {
        conversionSink.add(data);
        isClosed = true;
        conversionSink.close();
      }
      return boundedSink.takeBytes();
    } finally {
      if (!isClosed) {
        try {
          conversionSink.close();
        } catch (_) {
          // Suppress secondary cleanup exceptions on abort path to preserve primary bomb exception
        }
      }
    }
  }

  static String getExecutableDir() {
    final execPath = Platform.resolvedExecutable;
    return File(execPath).parent.path;
  }

  static void setNativeLibPaths() {
    final execDir = getExecutableDir();
    final List<String> candidatePaths = [
      path.join(execDir, 'data', 'flutter_assets', 'native_libs'),
      path.join(execDir, 'native_libs'),
      if (kDebugMode || Platform.environment.containsKey('FLUTTER_TEST'))
        path.join(Directory.current.path, 'native_libs'),
      execDir,
    ];

    final List<String> expectedLibs = Platform.isWindows
        ? const ['eslz4-win64.dll', 'esbrotli-win64.dll', 'eszstd-win64.dll']
        : Platform.isMacOS
            ? const ['eslz4-mac64.dylib', 'esbrotli-mac64.dylib', 'eszstd-mac64.dylib']
            : const ['eslz4-linux64.so', 'esbrotli-linux64.so', 'eszstd-linux64.so'];

    final String basePath = candidatePaths.firstWhere(
      (dir) => expectedLibs.every((lib) => File(path.join(dir, lib)).existsSync()),
      orElse: () => candidatePaths.firstWhere(
        (dir) => File(path.join(dir, expectedLibs.first)).existsSync(),
        orElse: () => candidatePaths.firstWhere(
          (dir) => Directory(dir).existsSync(),
          orElse: () => candidatePaths.first,
        ),
      ),
    );

    String lz4LibPath;
    if (Platform.isWindows) {
      lz4LibPath = path.join(basePath, 'eslz4-win64.dll');
    } else if (Platform.isLinux) {
      lz4LibPath = path.join(basePath, 'eslz4-linux64.so');
    } else if (Platform.isMacOS) {
      lz4LibPath = path.join(basePath, 'eslz4-mac64.dylib');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
    Lz4Codec.libraryPath = lz4LibPath;

    String brotliLibPath;
    if (Platform.isWindows) {
      brotliLibPath = path.join(basePath, 'esbrotli-win64.dll');
    } else if (Platform.isLinux) {
      brotliLibPath = path.join(basePath, 'esbrotli-linux64.so');
    } else if (Platform.isMacOS) {
      brotliLibPath = path.join(basePath, 'esbrotli-mac64.dylib');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
    BrotliCodec.libraryPath = brotliLibPath;

    String zstdLibPath;
    if (Platform.isWindows) {
      zstdLibPath = path.join(basePath, 'eszstd-win64.dll');
    } else if (Platform.isLinux) {
      zstdLibPath = path.join(basePath, 'eszstd-linux64.so');
    } else if (Platform.isMacOS) {
      zstdLibPath = path.join(basePath, 'eszstd-mac64.dylib');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
    ZstdCodec.libraryPath = zstdLibPath;
  }
}

class DecompressionBombException implements Exception {
  final int maxBytes;
  final int currentBytes;
  const DecompressionBombException(this.maxBytes, this.currentBytes);

  @override
  String toString() =>
      'DecompressionBombException: Exceeded maximum allowed uncompressed size of $maxBytes bytes (encountered $currentBytes bytes)';
}

class BoundedByteSink extends ByteConversionSinkBase {
  final int maxBytes;
  final BytesBuilder _builder = BytesBuilder();
  int _totalBytes = 0;

  BoundedByteSink({required this.maxBytes});

  @override
  void add(List<int> chunk) {
    _checkLimit(chunk.length);
    _builder.add(chunk);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    RangeError.checkValidRange(start, end, chunk.length);
    final sliceLen = end - start;
    _checkLimit(sliceLen);
    if (chunk is Uint8List) {
      _builder.add(Uint8List.view(chunk.buffer, chunk.offsetInBytes + start, sliceLen));
    } else {
      _builder.add(chunk.sublist(start, end));
    }
  }

  void _checkLimit(int incoming) {
    _totalBytes += incoming;
    if (_totalBytes > maxBytes) {
      throw DecompressionBombException(maxBytes, _totalBytes);
    }
  }

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}

