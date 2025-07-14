import 'dart:convert';
import 'dart:typed_data';
import 'package:qrypt/models/compression_method.dart';
import '../services/tag_manager.dart';
import 'encryption_method.dart';
import 'obfuscation_method.dart';

class Qrypt{
  String text='';
  Uint8List compressedText=utf8.encode('');
  List<int> deCompressedText=utf8.encode('');
  late final EncryptionMethod encryption;
  late final ObfuscationMethod obfuscation;
  late final CompressionMethod compression;
  bool useTag=false;
  String tag='';
  Qrypt.withTag({required this.text,required this.encryption,required this.obfuscation,required this.compression,required this.useTag}){
    if(useTag == true){
      TagManager.setTag(this);
    }
  }

  Qrypt.autoDecrypt({required this.text}){
    useTag = true;
  }
  Qrypt({required this.text,required this.encryption,required this.obfuscation,required this.compression});

  EncryptionMethod getEncryptionMethod(){
    return encryption;
  }
  ObfuscationMethod getObfuscationMethod(){
    return obfuscation;
  }
  CompressionMethod getCompressionMethod(){
    return compression;
  }
}

