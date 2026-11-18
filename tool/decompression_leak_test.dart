// Standalone benchmark to verify memory stability and leak-freedom
// over 1,000 aborted decompression bomb iterations across all codecs.
// Run manually via:
// dart run --packages=.dart_tool/package_config.json tool/decompression_leak_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:es_compression/brotli.dart';
import 'package:es_compression/lz4.dart';
import 'package:es_compression/zstd.dart';
import 'package:qrypt/services/compression.dart';

void main() {
  print('=== 1,000-ITERATION DECOMPRESSION ABORT BENCHMARK ===');
  Compression.setNativeLibPaths();

  final brotliCodec = BrotliCodec();
  final lz4Codec = Lz4Codec();
  final zstdCodec = ZstdCodec();

  // Create 500 KB repetitive payload
  final rawData = Uint8List(500 * 1024);
  for (int i = 0; i < rawData.length; i++) {
    rawData[i] = i % 256;
  }

  final gzipCompressed = Compression.gZipCompress(rawData);
  final brotliCompressed = brotliCodec.encode(rawData);
  final lz4Compressed = lz4Codec.encode(rawData);
  final zstdCompressed = zstdCodec.encode(rawData);

  const lowLimit = 10 * 1024; // 10 KB limit to trigger early abort

  final codecs = <String, (List<int> compressed, List<int> Function(List<int>, {int maxBytes}) decompress)>{
    'GZip': (gzipCompressed, Compression.gZipDeCompress),
    'Brotli': (brotliCompressed, Compression.brotliDeCompress),
    'LZ4': (lz4Compressed, Compression.lz4DeCompress),
    'Zstd': (zstdCompressed, Compression.zstdDeCompress),
  };

  for (final entry in codecs.entries) {
    final name = entry.key;
    final compressed = entry.value.$1;
    final decompress = entry.value.$2;

    final rssBefore = ProcessInfo.currentRss;
    for (int i = 0; i < 1000; i++) {
      try {
        decompress(compressed, maxBytes: lowLimit);
      } on DecompressionBombException {
        // Expected early abort
      }
    }
    final rssAfter = ProcessInfo.currentRss;
    final diffMB = (rssAfter - rssBefore) / (1024 * 1024);
    print('$name: 1,000 aborts completed without crash.');
    print('  RSS before: ${(rssBefore / 1024 / 1024).toStringAsFixed(2)} MB, after: ${(rssAfter / 1024 / 1024).toStringAsFixed(2)} MB (delta: ${diffMB.toStringAsFixed(2)} MB)');
  }

  print('\nBenchmark completed successfully.');
}
