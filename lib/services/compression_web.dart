import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

const String _kNativeCodecWebError =
    'LZ4, Brotli, and Zstd require native es_compression binaries and are unavailable in Flutter Web preview. Use GZip or None on web.';

class Compression {
  /// Default expansion ceiling for clipboard/text-fed payloads (25 MB).
  static const int defaultMaxDecompressedBytes = 25 * 1024 * 1024;

  /// Compresses data using GZip (pure Dart via package:archive).
  static Uint8List gZipCompress(List<int> data) {
    final encoder = GZipEncoder();
    return Uint8List.fromList(encoder.encode(data));
  }

  /// Decompresses data using GZip with size guard on Flutter Web.
  static List<int> gZipDeCompress(
    List<int> compressedData, {
    int maxBytes = defaultMaxDecompressedBytes,
  }) {
    if (compressedData.isEmpty) return <int>[];
    final decoded = GZipDecoder().decodeBytes(compressedData);
    if (decoded.length > maxBytes) {
      throw DecompressionBombException(maxBytes, decoded.length);
    }
    return decoded;
  }

  static Uint8List lz4Compress(List<int> data) {
    throw UnsupportedError(_kNativeCodecWebError);
  }

  static List<int> lz4DeCompress(
    List<int> compressedData, {
    int maxBytes = defaultMaxDecompressedBytes,
  }) {
    throw UnsupportedError(_kNativeCodecWebError);
  }

  static Uint8List brotliCompress(List<int> data) {
    throw UnsupportedError(_kNativeCodecWebError);
  }

  static List<int> brotliDeCompress(
    List<int> compressedData, {
    int maxBytes = defaultMaxDecompressedBytes,
  }) {
    throw UnsupportedError(_kNativeCodecWebError);
  }

  static Uint8List zstdCompress(List<int> data) {
    throw UnsupportedError(_kNativeCodecWebError);
  }

  static List<int> zstdDeCompress(
    List<int> compressedData, {
    int maxBytes = defaultMaxDecompressedBytes,
  }) {
    throw UnsupportedError(_kNativeCodecWebError);
  }

  static String getExecutableDir() => '';

  static void setNativeLibPaths() {
    // Native es_compression libraries are not loaded on Flutter Web.
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
      _builder.add(
        Uint8List.view(chunk.buffer, chunk.offsetInBytes + start, sliceLen),
      );
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
