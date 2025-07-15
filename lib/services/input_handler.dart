import 'dart:convert';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/tag_manager.dart';

import '../models/Qrypt.dart';
import '../models/compression_method.dart';
import '../models/encryption_method.dart';
import '../models/obfuscation_method.dart';
import '../providers/encryption_providers.dart';
import 'aes_encryption.dart';
import 'obfuscate.dart';

class InputHandler{
  Qrypt handleCompression(Qrypt qrypt){
    Uint8List compText;
    switch(qrypt.getCompressionMethod()){
      case CompressionMethod.none:
        compText = utf8.encode(qrypt.text);
        qrypt.compressedText = compText;
        return qrypt;
      case CompressionMethod.gZip:
        compText = Compression.gZipCompress(utf8.encode(qrypt.text));
        qrypt.compressedText = compText;
        return qrypt;

      case CompressionMethod.lZ4:
        compText = Compression.lz4Compress(utf8.encode(qrypt.text));
        qrypt.compressedText = compText;
        return qrypt;
      case CompressionMethod.brotli:
        compText = Compression.brotliCompress(utf8.encode(qrypt.text));
        qrypt.compressedText = compText;
        return qrypt;
      case CompressionMethod.zstd:
        compText = Compression.zstdCompress(utf8.encode(qrypt.text));
        qrypt.compressedText = compText;
        return qrypt;
    }
  }
  Qrypt handleEncrypt(Qrypt qrypt){
    String? encryptedText=qrypt.text;
    switch(qrypt.getEncryptionMethod()){
      case EncryptionMethod.none:
        qrypt.text = qrypt.compressedText.toString();
        return qrypt;
      case EncryptionMethod.aesCbc:
        Map<String,String> encMap = Aes.encryptAesCbc(qrypt.compressedText);
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;

    }
  }
  Qrypt handleObfs(Qrypt qrypt){
    String? obfsText=qrypt.text;
    switch(qrypt.getObfuscationMethod()){
      case ObfuscationMethod.none:
        return qrypt;
      case ObfuscationMethod.fa1:

        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationFA1Map);
        // print('crypt txt is:${obfsText}');
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.fa2:
        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationFA2Map);
        qrypt.text = obfsText;
        return qrypt;
    }
  }

  Qrypt handleDeObfs(Qrypt qrypt){
    String? obfsText=qrypt.text;
    switch(qrypt.getObfuscationMethod()){
      case ObfuscationMethod.none:
        return qrypt;
      case ObfuscationMethod.fa1:

        obfsText = Obfuscate.deobfuscateText(qrypt.text, obfuscationFA1Map);
        // print('crypt txt is:${obfsText}');
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.fa2:
        obfsText = Obfuscate.deobfuscateText(qrypt.text, obfuscationFA2Map);
        qrypt.text = obfsText;
        return qrypt;
    }
  }
  Qrypt handleDecrypt(Qrypt qrypt){
    switch(qrypt.getEncryptionMethod()){
      case EncryptionMethod.none:
        qrypt.deCompressedText = utf8.encode(qrypt.text);
        return qrypt;
      case EncryptionMethod.aesCbc:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-CBC format');
        qrypt.deCompressedText = Aes.decryptAesCbc(parts[0], parts[1]); //to be decompressed in the next phase
        return qrypt;
    }
  }
  Qrypt handleDeCompression(Qrypt qrypt){
    switch(qrypt.getCompressionMethod()){
      case CompressionMethod.none:
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.gZip:
        qrypt.deCompressedText = Compression.gZipDeCompress(qrypt.deCompressedText);
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;

      case CompressionMethod.lZ4:
        qrypt.deCompressedText = Compression.lz4DeCompress(qrypt.deCompressedText);
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.brotli:
        qrypt.deCompressedText = Compression.brotliDeCompress(qrypt.deCompressedText);
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.zstd:
        qrypt.deCompressedText = Compression.zstdDeCompress(qrypt.deCompressedText);
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
    }
  }

  Qrypt handleProcess(Qrypt qrypt){
    qrypt = handleCompression(qrypt);
    qrypt = handleEncrypt(qrypt);
    qrypt.text = qrypt.tag+qrypt.text;
    qrypt = handleObfs(qrypt);
    return qrypt;
  }

  Qrypt handleDeProcess(Qrypt qrypt,bool useTag){
    if(!useTag){
      qrypt  = handleDeObfs(qrypt);
      qrypt  = handleDecrypt(qrypt);
      qrypt  = handleDeCompression(qrypt);
    }else{
      String? tag = TagManager.matchedTag(qrypt.text);
      if (tag == null) {
        qrypt.text = 'Invalid tag format';
        // throw FormatException('Invalid tag format');
      }else{
        print('tag is $tag');
        qrypt.text = qrypt.text.substring(tag.length);
        print('tag removed text: ${qrypt.text}');
        final methods = TagManager.getMethodsFromTag(tag);
        qrypt.obfuscation = methods!.obfuscation;
        qrypt.encryption = methods.encryption;
        qrypt.compression = methods.compression;
        qrypt  = handleDeObfs(qrypt);
        qrypt  = handleDecrypt(qrypt);
        qrypt  = handleDeCompression(qrypt);
      }

    }
    return qrypt;
  }



  static List<String> parseByColon(String input) {
    List<String> parts;
    parts= input.split(':');
    print('parsed the text with size ${parts.length} : ${parts[0]} and ${parts[1]} ');
    return input.split(':');
  }
}


// class DeQrypt{
//   String text="";
//   late final EncryptionMethod encryption;
//   late final ObfuscationMethod obfuscation;
//   bool useTag=false;
//   String? tag;
//   DeQrypt.withTag({required this.text,required this.encryption,required this.obfuscation,this.tag}){
//     useTag=true;
//   }
//   DeQrypt({required this.text,required this.encryption,required this.obfuscation});
// }