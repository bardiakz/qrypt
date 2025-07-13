import 'dart:convert';
import 'dart:typed_data';

import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/services/compression.dart';

import '../models/Qrypt.dart';
import '../models/compression_method.dart';
import '../models/encryption_method.dart';
import '../models/obfuscation_method.dart';
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
        encryptedText = '${Aes.encryptMessage(qrypt.compressedText)['ciphertext']}:${Aes.encryptMessage(qrypt.compressedText)['iv']!}';
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
  Qrypt handleProcess(Qrypt qrypt){
    qrypt = handleCompression(qrypt);
    qrypt = handleEncrypt(qrypt);
    qrypt.text = qrypt.tag+qrypt.text;
    qrypt = handleObfs(qrypt);
    return qrypt;
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