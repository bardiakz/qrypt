/// Thrown when an encryption or decryption operation requires a cryptographic key
/// that was neither supplied nor found in secure storage.
class MissingKeyException implements Exception {
  final String message;

  const MissingKeyException(this.message);

  @override
  String toString() => 'MissingKeyException: $message';
}

/// Thrown when plaintext or compressed data exceeds the maximum payload size
/// supported by RSA-OAEP for the given key size.
class RsaPayloadTooLargeException implements Exception {
  final int maxBytes;
  final int actualBytes;
  const RsaPayloadTooLargeException({
    required this.maxBytes,
    required this.actualBytes,
  });

  @override
  String toString() =>
      'RSA-OAEP-256 can encrypt at most $maxBytes bytes '
      '(your data compressed to $actualBytes bytes). '
      'Use AES-GCM for larger payloads.';
}

