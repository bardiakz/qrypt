/// Thrown when an encryption or decryption operation requires a cryptographic key
/// that was neither supplied nor found in secure storage.
class MissingKeyException implements Exception {
  final String message;

  const MissingKeyException(this.message);

  @override
  String toString() => 'MissingKeyException: $message';
}
