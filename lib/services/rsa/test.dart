import 'package:pointycastle/asymmetric/api.dart';
import 'package:asn1lib/asn1lib.dart' as asn1lib;
import 'dart:convert';
import 'dart:typed_data';

RSAPublicKey? _parsePublicKey(String pemString) {
  try {
    final publicKeyDER = _decodePEM(pemString);
    if (publicKeyDER.isEmpty) {
      print('Empty DER data after PEM decoding');
      return null;
    }

    print('DER data length: ${publicKeyDER.length}');
    print(
      'DER data (first 20 bytes): ${publicKeyDER.sublist(0, publicKeyDER.length > 20 ? 20 : publicKeyDER.length).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    var asn1Parser = asn1lib.ASN1Parser(publicKeyDER);
    var topLevelSeq = asn1Parser.nextObject();

    if (topLevelSeq is! asn1lib.ASN1Sequence ||
        topLevelSeq.elements.length != 2) {
      print('Invalid top-level sequence');
      return null;
    }

    var publicKeyBitString = topLevelSeq.elements[1];
    if (publicKeyBitString is! asn1lib.ASN1BitString) {
      print('Second element is not an ASN1BitString');
      return null;
    }

    var publicKeyBytes = publicKeyBitString.valueBytes();
    if (publicKeyBytes.isEmpty) {
      print('Empty public key bytes');
      return null;
    }

    print('Public key bytes length: ${publicKeyBytes.length}');
    print(
      'Public key bytes (first 20 bytes): ${publicKeyBytes.sublist(0, publicKeyBytes.length > 20 ? 20 : publicKeyBytes.length).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    print('Unused bits in BitString: ${publicKeyBitString.unusedbits}');

    // Skip the unused bits byte (first byte) if present
    if (publicKeyBytes[0] == 0x00 && publicKeyBitString.unusedbits == 0) {
      print('Skipping unused bits byte (0x00)');
      publicKeyBytes = publicKeyBytes.sublist(1);
      print(
        'Adjusted public key bytes (first 20 bytes): ${publicKeyBytes.sublist(0, publicKeyBytes.length > 20 ? 20 : publicKeyBytes.length).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
    }

    // Parse RSAPublicKey sequence
    try {
      var parser = asn1lib.ASN1Parser(publicKeyBytes);
      var publicKeySeq = parser.nextObject();

      if (publicKeySeq is! asn1lib.ASN1Sequence ||
          publicKeySeq.elements.length < 2) {
        print('Invalid RSAPublicKey sequence');
        return null;
      }

      var modulusElement = publicKeySeq.elements[0];
      var exponentElement = publicKeySeq.elements[1];

      if (modulusElement is! asn1lib.ASN1Integer ||
          exponentElement is! asn1lib.ASN1Integer) {
        print('Modulus or exponent is not an ASN1Integer');
        return null;
      }

      var modulus = modulusElement.valueAsBigInteger;
      var exponent = exponentElement.valueAsBigInteger;

      print('Modulus: $modulus');
      print('Exponent: $exponent');
      return RSAPublicKey(modulus, exponent);
    } catch (e, stackTrace) {
      print('ASN1Parser failed, attempting manual parsing: $e');
      print('Stack trace: $stackTrace');

      // Manual parsing
      int pos = 0;
      print(
        'Manual parsing starting at position $pos, byte: ${publicKeyBytes[pos].toRadixString(16).padLeft(2, '0')}',
      );
      if (publicKeyBytes[pos] != 0x30) {
        print(
          'Expected sequence tag (0x30) at position 0, found ${publicKeyBytes[pos].toRadixString(16).padLeft(2, '0')}',
        );
        return null;
      }
      pos++;

      // Decode sequence length
      int length;
      if (publicKeyBytes[pos] < 0x80) {
        length = publicKeyBytes[pos];
        pos++;
      } else {
        int lengthBytes = publicKeyBytes[pos] & 0x7F;
        pos++;
        length = 0;
        for (int i = 0; i < lengthBytes; i++) {
          if (pos >= publicKeyBytes.length) {
            print(
              'Unexpected end of bytes while reading length at position $pos',
            );
            return null;
          }
          length = (length << 8) + publicKeyBytes[pos];
          pos++;
        }
      }
      print('Sequence length: $length');

      // Parse modulus (INTEGER)
      if (pos >= publicKeyBytes.length || publicKeyBytes[pos] != 0x02) {
        print(
          'Expected integer tag (0x02) for modulus at position $pos, found ${pos < publicKeyBytes.length ? publicKeyBytes[pos].toRadixString(16).padLeft(2, '0') : 'EOF'}',
        );
        return null;
      }
      pos++;

      int modulusLength;
      if (publicKeyBytes[pos] < 0x80) {
        modulusLength = publicKeyBytes[pos];
        pos++;
      } else {
        int lengthBytes = publicKeyBytes[pos] & 0x7F;
        pos++;
        modulusLength = 0;
        for (int i = 0; i < lengthBytes; i++) {
          if (pos >= publicKeyBytes.length) {
            print(
              'Unexpected end of bytes while reading modulus length at position $pos',
            );
            return null;
          }
          modulusLength = (modulusLength << 8) + publicKeyBytes[pos];
          pos++;
        }
      }
      print('Modulus length: $modulusLength');

      if (pos + modulusLength > publicKeyBytes.length) {
        print('Modulus length exceeds available bytes at position $pos');
        return null;
      }
      var modulusBytes = publicKeyBytes.sublist(pos, pos + modulusLength);
      pos += modulusLength;
      var modulus = BigInt.parse(
        modulusBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );
      print('Modulus: $modulus');

      // Parse exponent (INTEGER)
      if (pos >= publicKeyBytes.length || publicKeyBytes[pos] != 0x02) {
        print(
          'Expected integer tag (0x02) for exponent at position $pos, found ${pos < publicKeyBytes.length ? publicKeyBytes[pos].toRadixString(16).padLeft(2, '0') : 'EOF'}',
        );
        return null;
      }
      pos++;

      int exponentLength;
      if (publicKeyBytes[pos] < 0x80) {
        exponentLength = publicKeyBytes[pos];
        pos++;
      } else {
        int lengthBytes = publicKeyBytes[pos] & 0x7F;
        pos++;
        exponentLength = 0;
        for (int i = 0; i < lengthBytes; i++) {
          if (pos >= publicKeyBytes.length) {
            print(
              'Unexpected end of bytes while reading exponent length at position $pos',
            );
            return null;
          }
          exponentLength = (exponentLength << 8) + publicKeyBytes[pos];
          pos++;
        }
      }
      print('Exponent length: $exponentLength');

      if (pos + exponentLength > publicKeyBytes.length) {
        print('Exponent length exceeds available bytes at position $pos');
        return null;
      }
      var exponentBytes = publicKeyBytes.sublist(pos, pos + exponentLength);
      var exponent = BigInt.parse(
        exponentBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );
      print('Exponent: $exponent');

      return RSAPublicKey(modulus, exponent);
    }
  } catch (e, stackTrace) {
    print('Error parsing public key: $e');
    print('Stack trace: $stackTrace');
    return null;
  }
}

Uint8List _decodePEM(String pem) {
  try {
    if (pem.trim().isEmpty) {
      throw FormatException('Empty PEM string');
    }

    String normalizedPem = pem
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    print('Normalized PEM:\n$normalizedPem');

    int startMarkerStart = normalizedPem.indexOf('-----BEGIN');
    if (startMarkerStart == -1) {
      throw FormatException('Invalid PEM format: missing BEGIN marker');
    }

    int startMarkerEnd = normalizedPem.indexOf('-----', startMarkerStart + 5);
    if (startMarkerEnd == -1) {
      throw FormatException('Invalid PEM format: malformed BEGIN marker');
    }

    int endMarkerStart = normalizedPem.indexOf('-----END');
    if (endMarkerStart == -1) {
      throw FormatException('Invalid PEM format: missing END marker');
    }

    String base64Content = normalizedPem
        .substring(startMarkerEnd + 5, endMarkerStart)
        .trim();
    base64Content = base64Content.replaceAll(RegExp(r'\s+'), '');

    if (base64Content.isEmpty) {
      throw FormatException('Invalid PEM format: empty content');
    }

    if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(base64Content)) {
      throw FormatException('Invalid PEM format: invalid base64 characters');
    }

    return base64.decode(base64Content);
  } catch (e) {
    print('PEM decode error: $e');
    rethrow;
  }
}

void main() {
  const pemString = '''-----BEGIN PUBLIC KEY-----
MIGeMA0GCSqGSIb3DQEBAQUAA4GMADCBiAKBgH48Na3S2/D6fQvCi/ILLu3E44hR
xQ9mWzOIlPGs5O3kvEfK2UbLN4oNaSQOS5xDQcHY2cL9CXPrYuNKEmPiNOat7rr2
XCy00V57riMIxdX2luNJwq0U/k5MRARdQHOMU1gyOhoqUDrPFNV8kTtiIHglEBXw
Gisj2KIkP8qmtzEfAgMBAAE=
-----END PUBLIC KEY-----''';

  final publicKey = _parsePublicKey(pemString);
  if (publicKey != null) {
    print('Successfully parsed public key:');
    print('Modulus: ${publicKey.modulus}');
    print('Exponent: ${publicKey.exponent}');
  } else {
    print('Failed to parse public key');
  }
}
