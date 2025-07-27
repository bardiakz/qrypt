// ML-KEM Key Sizes enum
enum MLKemKeySize {
  kem512(512, "ML-KEM-512"),
  kem768(768, "ML-KEM-768"),
  kem1024(1024, "ML-KEM-1024");

  const MLKemKeySize(this.bits, this.displayName);

  final int bits;
  final String displayName;
}
