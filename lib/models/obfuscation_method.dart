abstract class Obfuscation {
  String get tag;
}
enum ObfuscationMethod {
  none,
  fa1,
  fa2,
  b64,
  rot13,
  xor,
  reverse,
}