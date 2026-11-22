import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/oqs_loader.dart';
import 'package:qrypt/services/kem/kem_service.dart';
import 'package:qrypt/services/ml_dsa/ml_dsa_key_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Native FFI Codecs & PQC roundtrip inside desktop runner', (tester) async {
    Compression.setNativeLibPaths();
    OqsLoader.initialize();

    final input = Uint8List.fromList(utf8.encode(
      'Live desktop GTK FFI integration test verification string 1234567890 '
      'testing symbol isolation and allocator parity across Brotli, LZ4, and Zstd.',
    ));

    // 1. Brotli (v1.2.1, -Wl,-Bsymbolic)
    final brotliEnc = Compression.brotliCompress(input);
    final brotliDec = Compression.brotliDeCompress(brotliEnc);
    expect(utf8.decode(brotliDec), equals(utf8.decode(input)));

    // 2. LZ4 (v1.9.4, -Wl,-Bsymbolic)
    final lz4Enc = Compression.lz4Compress(input);
    final lz4Dec = Compression.lz4DeCompress(lz4Enc);
    expect(utf8.decode(lz4Dec), equals(utf8.decode(input)));

    // 3. Zstd (v1.5.6, -Wl,-Bsymbolic)
    final zstdEnc = Compression.zstdCompress(input);
    final zstdDec = Compression.zstdDeCompress(zstdEnc);
    expect(utf8.decode(zstdDec), equals(utf8.decode(input)));

    // 4. ML-KEM via liboqs
    final kemService = KemKeyService();
    final kemPair = await kemService.generateKeyPair('DesktopRunnerKEM');
    final encResult = kemService.encapsulateWithPublicKey(kemPair.publicKey);
    final decapSecret = kemService.decapsulateWithSecretKey(
      encResult.ciphertext,
      kemPair.secretKey,
    );
    expect(decapSecret, equals(encResult.sharedSecret));

    // 5. ML-DSA via liboqs
    final dsaService = MlDsaKeyService();
    final dsaPair = await dsaService.generateKeyPair('DesktopRunnerDSA');
    final signature = dsaService.signMessage(input, dsaPair.secretKey);
    final verified = dsaService.verifySignature(input, signature, dsaPair.publicKey);
    expect(verified, isTrue);
  });
}
