import 'dart:convert';
import 'dart:typed_data';

import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/tag_manager.dart';

import '../models/Qrypt.dart';
import '../models/compression_method.dart';
import '../models/obfuscation_method.dart';
import 'aes_encryption.dart';
import 'obfuscate.dart';

class InputHandler {
  Qrypt handleCompression(Qrypt qrypt) {
    Uint8List compText;
    switch (qrypt.getCompressionMethod()) {
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

  Qrypt handleEncrypt(Qrypt qrypt) {
    String? encryptedText = qrypt.text;
    switch (qrypt.getEncryptionMethod()) {
      case EncryptionMethod.none:
        bool usesMappedObfuscation = [
          ObfuscationMethod.en1,
          ObfuscationMethod.en2,
          ObfuscationMethod.fa1,
          ObfuscationMethod.fa2,
        ].contains(qrypt.getObfuscationMethod());

        bool usesBase64Obfuscation =
            qrypt.getObfuscationMethod() == ObfuscationMethod.b64;

        if (usesMappedObfuscation) {
          // For mapped obfuscations, convert to hex
          qrypt.text = qrypt.compressedText
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join('');
        } else if (usesBase64Obfuscation) {
          // For b64 obfuscation, keep as raw bytes (don't pre-encode)
          qrypt.text = String.fromCharCodes(qrypt.compressedText);
        } else {
          // For other obfuscations (rot13, xor, etc.), use base64
          qrypt.text = base64.encode(qrypt.compressedText);
        }
        return qrypt;
      case EncryptionMethod.aesCbc:
        Map<String, String> encMap = Aes.encryptAesCbc(qrypt.compressedText);
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;

      case EncryptionMethod.aesCtr:
        Map<String, String> encMap = Aes.encryptAesCtr(qrypt.compressedText);
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;
      case EncryptionMethod.aesGcm:
        Map<String, String> encMap = Aes.encryptAesGcm(qrypt.compressedText);
        encryptedText = '${encMap['ciphertext']}:${encMap['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;
    }
  }

  Qrypt handleObfs(Qrypt qrypt) {
    String? obfsText = qrypt.text;
    switch (qrypt.getObfuscationMethod()) {
      case ObfuscationMethod.none:
        return qrypt;
      case ObfuscationMethod.en1:
        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationEN1Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.en2:
        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationEN2Map);
        qrypt.text = obfsText;
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
      case ObfuscationMethod.b64:
        obfsText = Obfuscate.obfuscateBase64(qrypt.text);
        qrypt.text = obfsText;
        return qrypt;

      case ObfuscationMethod.rot13:
        obfsText = Obfuscate.obfuscateROT13(qrypt.text);
        qrypt.text = obfsText;
        return qrypt;

      case ObfuscationMethod.xor:
        obfsText = Obfuscate.obfuscateXOR(qrypt.text, 42);
        qrypt.text = obfsText;
        return qrypt;

      // case ObfuscationMethod.reverse:
      //   obfsText = Obfuscate.obfuscateReverse(qrypt.text);
      //   qrypt.text = obfsText;
      //   return qrypt;
    }
  }

  Qrypt handleDeObfs(Qrypt qrypt) {
    String? obfsText = qrypt.text;
    switch (qrypt.getObfuscationMethod()) {
      case ObfuscationMethod.none:
        return qrypt;
      case ObfuscationMethod.en1:
        obfsText = Obfuscate.deobfuscateText(qrypt.text, obfuscationEN1Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.en2:
        obfsText = Obfuscate.deobfuscateText(qrypt.text, obfuscationEN2Map);
        qrypt.text = obfsText;
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
      case ObfuscationMethod.b64:
        obfsText = Obfuscate.deobfuscateBase64(qrypt.text);
        qrypt.text = obfsText;
        return qrypt;

      case ObfuscationMethod.rot13:
        obfsText = Obfuscate.deobfuscateROT13(qrypt.text);
        qrypt.text = obfsText;
        return qrypt;

      case ObfuscationMethod.xor:
        // Use the same key as obfuscation
        obfsText = Obfuscate.deobfuscateXOR(qrypt.text, 42); // Same key
        qrypt.text = obfsText;
        return qrypt;

      // case ObfuscationMethod.reverse:
      //   obfsText = Obfuscate.deobfuscateReverse(qrypt.text);
      //   qrypt.text = obfsText;
      //   return qrypt;
    }
  }

  Qrypt handleDecrypt(Qrypt qrypt) {
    switch (qrypt.getEncryptionMethod()) {
      case EncryptionMethod.none:
        bool usesMappedObfuscation = [
          ObfuscationMethod.en1,
          ObfuscationMethod.en2,
          ObfuscationMethod.fa1,
          ObfuscationMethod.fa2,
        ].contains(qrypt.getObfuscationMethod());

        bool usesBase64Obfuscation =
            qrypt.getObfuscationMethod() == ObfuscationMethod.b64;

        if (usesMappedObfuscation) {
          // Convert hex back to bytes
          List<int> bytes = [];
          for (int i = 0; i < qrypt.text.length; i += 2) {
            String hexByte = qrypt.text.substring(i, i + 2);
            bytes.add(int.parse(hexByte, radix: 16));
          }
          qrypt.deCompressedText = Uint8List.fromList(bytes);
        } else if (usesBase64Obfuscation) {
          // For b64 obfuscation, convert string back to bytes
          qrypt.deCompressedText = Uint8List.fromList(qrypt.text.codeUnits);
        } else {
          // For other obfuscations, decode base64
          qrypt.deCompressedText = base64.decode(qrypt.text);
        }
        return qrypt;
      case EncryptionMethod.aesCbc:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-CBC format');
        qrypt.deCompressedText = Aes.decryptAesCbc(
          parts[0],
          parts[1],
        ); //to be decompressed in the next phase
        return qrypt;
      case EncryptionMethod.aesCtr:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-CTR format');
        qrypt.deCompressedText = Aes.decryptAesCtr(
          parts[0],
          parts[1],
        ); //to be decompressed in the next phase
        return qrypt;
      case EncryptionMethod.aesGcm:
        List<String> parts = parseByColon(qrypt.text);
        if (parts.length != 2) throw FormatException('Invalid AES-GCM format');
        qrypt.deCompressedText = Aes.decryptAesGcm(
          parts[0],
          parts[1],
        )!; //to be decompressed in the next phase
        return qrypt;
    }
  }

  Qrypt handleDeCompression(Qrypt qrypt) {
    switch (qrypt.getCompressionMethod()) {
      case CompressionMethod.none:
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.gZip:
        qrypt.deCompressedText = Compression.gZipDeCompress(
          qrypt.deCompressedText,
        );
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;

      case CompressionMethod.lZ4:
        qrypt.deCompressedText = Compression.lz4DeCompress(
          qrypt.deCompressedText,
        );
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.brotli:
        qrypt.deCompressedText = Compression.brotliDeCompress(
          qrypt.deCompressedText,
        );
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
      case CompressionMethod.zstd:
        qrypt.deCompressedText = Compression.zstdDeCompress(
          qrypt.deCompressedText,
        );
        qrypt.text = utf8.decode(qrypt.deCompressedText);
        return qrypt;
    }
  }

  Qrypt handleProcess(Qrypt qrypt) {
    qrypt = handleCompression(qrypt);
    qrypt = handleEncrypt(qrypt);
    qrypt.text = qrypt.tag + qrypt.text;
    qrypt = handleObfs(qrypt);
    return qrypt;
  }

  Qrypt handleDeProcess(Qrypt qrypt, bool useTag) {
    if (!useTag) {
      qrypt = handleDeObfs(qrypt);
      qrypt = handleDecrypt(qrypt);
      qrypt = handleDeCompression(qrypt);
    } else {
      String? tag = TagManager.matchedTag(qrypt.text);
      if (tag == null) {
        qrypt.text = 'Invalid tag format';
        // throw FormatException('Invalid tag format');
      } else {
        print('tag is $tag');
        qrypt.text = qrypt.text.substring(tag.length);
        print('tag removed text: ${qrypt.text}');
        final methods = TagManager.getMethodsFromTag(tag);
        qrypt.obfuscation = methods!.obfuscation;
        qrypt.encryption = methods.encryption;
        qrypt.compression = methods.compression;
        qrypt = handleDeObfs(qrypt);
        qrypt = handleDecrypt(qrypt);
        qrypt = handleDeCompression(qrypt);
      }
    }
    return qrypt;
  }

  static List<String> parseByColon(String input) {
    List<String> parts;
    parts = input.split(':');
    print(
      'parsed the text with size ${parts.length} : ${parts[0]} and ${parts[1]} ',
    );
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
