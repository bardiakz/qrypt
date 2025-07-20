import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:qrypt/models/encryption_method.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/rsa/rsa_key_service.dart';
import 'package:qrypt/services/tag_manager.dart';

import '../models/Qrypt.dart';
import '../models/compression_method.dart';
import '../models/obfuscation_method.dart';
import '../models/rsa_key_pair.dart';
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

  Future<Qrypt> handleEncrypt(Qrypt qrypt) async {
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
      case EncryptionMethod.rsa:
        try {
          // Check if a valid RSA public key is provided
          if (qrypt.rsaReceiverPublicKey.isEmpty ||
              qrypt.rsaReceiverPublicKey == "noPublicKey" ||
              !qrypt.rsaReceiverPublicKey.contains("BEGIN PUBLIC KEY")) {
            throw Exception('No valid RSA public key provided for encryption');
          }

          RSAKeyService rsa = RSAKeyService();
          // Convert compressed bytes to string for RSA encryption
          String textToEncrypt = base64.encode(qrypt.compressedText);
          String encryptedResult = await rsa.encryptWithPublicKey(
            textToEncrypt,
            qrypt.rsaReceiverPublicKey,
          );
          qrypt.text = encryptedResult;
          return qrypt;
        } catch (e) {
          if (kDebugMode) {
            print('RSA encryption failed: $e');
          }
          throw Exception('RSA encryption failed: $e');
        }
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

  Future<Qrypt> handleDecrypt(Qrypt qrypt) async {
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
      case EncryptionMethod.rsa:
        try {
          qrypt.rsaKeyPair = RSAKeyPair(
            id: '',
            name: '',
            publicKey: '',
            privateKey: '''-----BEGIN PRIVATE KEY-----
MIIFvQIBADANBgkqhkiG9w0BAQEFAASCBacwggWjAgEAAoIBAQCHFn01QRPaZVeM
i/iA76xf9uqCNuhSTd0Y98HVkpeL/Y8/XhoOEG30Bpn7Eh81vMYxpeiAswcr/nUO
KzdL0MyimMPQtBZvco2A9ors1ArD4u3P+pHZS00Paz0pivdgV4v/tBJd29ZrU5nR
Dh72LRM7IUfLMd/zd2spqkb7SIJ7b6oibon5pwkDOK5ZDVHhuQiG0bEOWS4vZvs6
g/R/uMOMoNlGVD14QFWoR1nlYy7GpgzjD96HEayyEC58nuAufQbEWBn2rTmeAXPq
i/K/MZKwrncZOa1emUEItw8MEO5Pg5KxVeZdMqvUkxiifL5cLgwu1myFx2Ub/9DX
RlJori/HAoIBABLVZtVy4kKzmFYm+Zl4UM78TMukvhUjd+zQNf0BuBEzY7JQ+070
qW+5L+SaLTG/xN4NJHI1A431pvo3ujjevnj41WwWf35AOUw+kzXbhjizPbaeV5E0
92Rr7hYJot2StxkKUPk2+hjyieJklpp5xFGdHTZOGMwH3S/s5oKIJHDy95oFHOIR
OIEPNvWLBhOcHICQGPifuoPaaQKf3e2rJmCjCW+Yz1+5gk6Pq3kIbDa0yXThvwKu
HS4NpRoYi2Krk24KBtBCK+2ZDwwwAEKTMKGr0+EwfcRuE9RryM1XJ0LnPtrhi0Ig
qYI7ih8KszW84Qu+jP1NUHy2fNavaHZow+ECggEAEtVm1XLiQrOYVib5mXhQzvxM
y6S+FSN37NA1/QG4ETNjslD7TvSpb7kv5JotMb/E3g0kcjUDjfWm+je6ON6+ePjV
bBZ/fkA5TD6TNduGOLM9tp5XkTT3ZGvuFgmi3ZK3GQpQ+Tb6GPKJ4mSWmnnEUZ0d
Nk4YzAfdL+zmgogkcPL3mgUc4hE4gQ829YsGE5wcgJAY+J+6g9ppAp/d7asmYKMJ
b5jPX7mCTo+reQhsNrTJdOG/Aq4dLg2lGhiLYquTbgoG0EIr7ZkPDDAAQpMwoavT
4TB9xG4T1GvIzVcnQuc+2uGLQiCpgjuKHwqzNbzhC76M/U1QfLZ81q9odmjD4QKB
gQDDPlMMIf+wsRLHA5F8i3OlplMEA2kNRVFAZo6rYd0JcNHva1odZAjRAVuiz8DA
7Uy/BatyU036JjdXlUUNxS1fUJRM9OUIulVB+le+uO9Hb5p+MTV9+EUh6APAMjw4
cXeIFEE2eSaWBdmQmb8GDLR7CHUlQQ5HW4LiIIgHht0hFwKBgQCxH/1f/4xgL6NI
kCAygccUA/oNUfjPbAGWtjwLIDzV/hHRfXI9M+Fj3nsjWqxz3og6yzsgkd+NHA9x
LYSJKpup/A8zhEMSjWfehZ9NpQ1VkZa3dLZL5WwgLa78q7bwQVQVFrk7ip27kI0y
c3dqdt2Y3YtswrYYn7UtVEDaHW600QKBgQCWYXS5zZ4RS/H4k4kFcqualScv2iiZ
7iANCHEvE+uaD+nDDN6V8KzRvsgD+Ryv/Ja2MvnAzuUqnTDXJsPPPWYbGgd/1shq
FosAjH/1CKBUV2OZevGGmyk0Wm45JPg5STwV9fPcryfHOa4/sAvv7u08LmF8VkVX
NOb0oLXlhjzf9QKBgCWa3xZ0kP8S3h3Xy54tg3Cyb3JIhwSyr5up0RGjpIbiTDIn
6gsoap/jak1VQOvQwSeKYmFF1yqEXJrwyQS+MRJj225alErqDrVltS6s7inOoSsN
8m4mpVAnotEuO8bCd/GKQ4VqppZd2Dxv21iVJ/L+hk1vAW406ihXjPVB7nEhAoGB
AJPXheOKta1w/K3JUV1ThbRnFuC1uDhBcPvJ9nbFY0PLUP+PXEMLAVNOlxST5LOK
3Zd/ZJWStAW4ad7MnUFvnD/hLgkqYkJ8J5IGdCBRMc5jc+RtiCBCE58Y0IAT7dYx
+t5Ep1/HYKSrKaKxFmHYG2bcFxgpC4BOBYEWAf/ePXI2
-----END PRIVATE KEY-----''',
            createdAt: DateTime.now(),
          );
          // Check if a valid RSA private key is provided
          if (qrypt.rsaKeyPair!.privateKey.isEmpty ||
              qrypt.rsaKeyPair!.privateKey == "noPrivateKey" ||
              !qrypt.rsaKeyPair!.privateKey.contains("BEGIN PRIVATE KEY")) {
            throw Exception('No valid RSA private key provided for decryption');
          }

          RSAKeyService rsa = RSAKeyService();
          // Decrypt the RSA encrypted text
          String decryptedResult = await rsa.decryptWithPrivateKey(
            qrypt.text,
            qrypt.rsaKeyPair!.privateKey,
          );

          // The decrypted result is base64 encoded compressed data
          qrypt.deCompressedText = base64.decode(decryptedResult);
          return qrypt;
        } catch (e) {
          if (kDebugMode) {
            print('RSA decryption failed: $e');
          }
          throw Exception('RSA decryption failed: $e');
        }
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

  Future<Qrypt> handleProcess(Qrypt qrypt) async {
    qrypt = handleCompression(qrypt);
    qrypt = await handleEncrypt(qrypt);
    qrypt.text = qrypt.tag + qrypt.text;
    qrypt = handleObfs(qrypt);
    return qrypt;
  }

  Future<Qrypt> handleDeProcess(Qrypt qrypt, bool useTag) async {
    if (!useTag) {
      qrypt = handleDeObfs(qrypt);
      qrypt = await handleDecrypt(qrypt);
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
        qrypt = await handleDecrypt(qrypt);
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
