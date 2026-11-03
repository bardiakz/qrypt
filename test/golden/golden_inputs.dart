import 'dart:math';

/// Deterministic inputs shared by the generator (old package) and the
/// compatibility test (new package). Everything here is ASCII, which is all
/// Qrypt ever feeds the obfuscation layer (hex, base64, ':' separators).
List<String> goldenInputs() {
  final r = Random(1234);
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return [
    '',
    '0',
    'a',
    '00',
    'deadbeef',
    'a1b2c3d4e5f60789',
    hex(64),
    hex(401),
    '${hex(40)}:${hex(24)}', // legacy AES-GCM layout: ciphertext:iv
    '${hex(40)}:${hex(32)}', // legacy AES-CBC/CTR layout
    'SGVsbG8gV29ybGQ+/w==',
    'AAEC+/8=',
  ];
}
