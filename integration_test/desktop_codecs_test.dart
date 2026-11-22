import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qrypt/models/kem_key_pair.dart';
import 'package:qrypt/models/ml_dsa_key_pair.dart';
import 'package:qrypt/services/compression.dart';
import 'package:qrypt/services/oqs_loader.dart';
import 'package:qrypt/services/kem/kem_key_storage_service.dart';
import 'package:qrypt/services/kem/kem_service.dart';
import 'package:qrypt/services/ml_dsa/ml_dsa_key_service.dart';
import 'package:qrypt/services/ml_dsa/ml_dsa_key_storage_service.dart';

class _InMemoryKemKeyStorageService extends KemKeyStorageService {
  final List<QryptKEMKeyPair> _items = [];

  @override
  Future<List<QryptKEMKeyPair>> getKeyPairs() async => List.of(_items);

  @override
  Future<void> saveKeyPair(QryptKEMKeyPair keyPair) async {
    _items.add(keyPair);
  }

  @override
  Future<void> deleteKeyPair(String id) async {
    _items.removeWhere((kp) => kp.id == id);
  }

  @override
  Future<void> updateKeyPair(QryptKEMKeyPair updatedKeyPair) async {
    final index = _items.indexWhere((kp) => kp.id == updatedKeyPair.id);
    if (index == -1) {
      throw Exception('Key pair with ID ${updatedKeyPair.id} not found');
    }
    _items[index] = updatedKeyPair;
  }

  @override
  Future<QryptKEMKeyPair?> getKeyPairById(String id) async {
    for (final kp in _items) {
      if (kp.id == id) return kp;
    }
    return null;
  }

  @override
  Future<bool> keyPairNameExists(String name) async {
    return _items.any((kp) => kp.name.toLowerCase() == name.toLowerCase());
  }
}

class _InMemoryMlDsaKeyStorageService extends MlDsaKeyStorageService {
  final List<QryptMLDSAKeyPair> _items = [];

  @override
  Future<List<QryptMLDSAKeyPair>> getKeyPairs() async => List.of(_items);

  @override
  Future<void> saveKeyPair(QryptMLDSAKeyPair keyPair) async {
    _items.add(keyPair);
  }

  @override
  Future<void> deleteKeyPair(String id) async {
    _items.removeWhere((kp) => kp.id == id);
  }

  @override
  Future<void> updateKeyPair(QryptMLDSAKeyPair updatedKeyPair) async {
    final index = _items.indexWhere((kp) => kp.id == updatedKeyPair.id);
    if (index == -1) {
      throw Exception('ML-DSA key pair with ID ${updatedKeyPair.id} not found');
    }
    _items[index] = updatedKeyPair;
  }

  @override
  Future<QryptMLDSAKeyPair?> getKeyPairById(String id) async {
    for (final kp in _items) {
      if (kp.id == id) return kp;
    }
    return null;
  }

  @override
  Future<bool> keyPairNameExists(String name) async {
    return _items.any((kp) => kp.name.toLowerCase() == name.toLowerCase());
  }

  @override
  Future<void> clearAllKeyPairs() async {
    _items.clear();
  }
}

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

    // 4. ML-KEM via liboqs (isolated in-memory storage; never touches OS keyring)
    final kemService = KemKeyService(
      storageService: _InMemoryKemKeyStorageService(),
    );
    try {
      final kemPair = await kemService.generateKeyPair('DesktopRunnerKEM');
      final encResult = kemService.encapsulateWithPublicKey(kemPair.publicKey);
      final decapSecret = kemService.decapsulateWithSecretKey(
        encResult.ciphertext,
        kemPair.secretKey,
      );
      expect(decapSecret, equals(encResult.sharedSecret));
    } finally {
      kemService.dispose();
    }

    // 5. ML-DSA via liboqs (isolated in-memory storage; never touches OS keyring)
    final dsaService = MlDsaKeyService(
      storageService: _InMemoryMlDsaKeyStorageService(),
    );
    try {
      final dsaPair = await dsaService.generateKeyPair('DesktopRunnerDSA');
      final signature = dsaService.signMessage(input, dsaPair.secretKey);
      final verified = dsaService.verifySignature(
        input,
        signature,
        dsaPair.publicKey,
      );
      expect(verified, isTrue);
    } finally {
      dsaService.dispose();
    }
  });
}
