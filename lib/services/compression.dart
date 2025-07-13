
import 'dart:typed_data';
import 'package:es_compression/lz4.dart';
import 'package:es_compression/brotli.dart';
import 'package:es_compression/zstd.dart';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';


class Compression{
  ///Compresses data using GZip
  static Uint8List gZipCompress(List<int> data) {
    final encoder = GZipEncoder();
    return Uint8List.fromList(encoder.encode(data));
  }

  ///Decompresses data using GZip
  static List<int> gZipDeCompress(List<int> compressedData) {
    final decoder = GZipDecoder();
    return decoder.decodeBytes(compressedData);
  }
  static Uint8List lz4Compress(List<int> data) {
    final encoder = Lz4Codec(level: 16);
    return Uint8List.fromList(encoder.encode(data));
  }
  static List<int> lz4DeCompress(List<int> compressedData) {
    final decoder = Lz4Codec();
    return decoder.decode(compressedData);
  }

  static Uint8List brotliCompress(List<int> data) {
    final encoder = BrotliCodec(level: 11);
    return Uint8List.fromList(encoder.encode(data));
  }
  static List<int> brotliDeCompress(List<int> compressedData) {
    final decoder = BrotliCodec();
    return decoder.decode(compressedData);
  }

  static Uint8List zstdCompress(List<int> data) {
    final encoder = ZstdCodec(level: 22);
    return Uint8List.fromList(encoder.encode(data));
  }
  static List<int> zstdDeCompress(List<int> compressedData) {
    final decoder = ZstdCodec();
    return decoder.decode(compressedData);
  }
}