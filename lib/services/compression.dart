
import 'dart:typed_data';

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
}