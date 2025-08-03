import 'dart:io';
import 'dart:typed_data';
import 'package:es_compression/lz4.dart';
import 'package:es_compression/brotli.dart';
import 'package:es_compression/zstd.dart';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class Compression {
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

  static String getExecutableDir() {
    final execPath = Platform.resolvedExecutable;
    return File(execPath).parent.path;
  }

  static void setNativeLibPaths() {
    final String basePath;
    // if (kDebugMode) {
    //   basePath = path.join(Directory.current.path, 'native_libs');
    // } else {
    //   basePath = path.join(getExecutableDir());
    // }
    basePath = path.join(getExecutableDir());

    String lz4LibPath;
    if (Platform.isWindows) {
      lz4LibPath = path.join(basePath, 'eslz4-win64.dll');
    } else if (Platform.isLinux) {
      lz4LibPath = path.join(basePath, 'lib/eslz4-linux64.so');
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
      brotliLibPath = path.join(basePath, 'lib/esbrotli-linux64.so');
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
      zstdLibPath = path.join(basePath, 'lib/eszstd-linux64.so');
    } else if (Platform.isMacOS) {
      zstdLibPath = path.join(basePath, 'eszstd-mac64.dylib');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
    ZstdCodec.libraryPath = zstdLibPath;
  }
}
