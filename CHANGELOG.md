# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.2.0] - 2026-11-04

### Added
- **Custom Obfuscation Map Management**:
  - Full profile management system for creating, storing, importing, and deleting custom substitution maps.
  - Built-in v2 maps are locked as immutable and removed from the Settings UI to prevent leaking substitution dictionaries to adversaries.
  - Cryptographically secure random map generator using `Random.secure()` from vetted pools (`en-words`, `fa-words`, `latin`, `persian`, `cyrillic`, `greek`, `hebrew`).
  - QR code generation and display (`qr_flutter: ^4.1.0`) for sharing custom maps visually.
  - Compact deterministic JSON sharing format (`{"v": 1, "n": name, "m": [17 symbols]}`) conforming to canonical hex + `:` order.
  - Single map import/export and "Export All Maps" bundle import/export.
  - Automatic profile name sanitization (strips control characters, collapses whitespace, clamps to 50 chars).
  - Strict validation against unvetted Unicode characters, missing domain keys, extra keys, and non-prefix-free token mappings.
- **Option 1A Decoupled Custom Tag Routing**:
  - Appended `ObfuscationMethod.custom` to the frozen enum.
  - Decoupled custom tags from the 840 built-in routing tags by caching the 70 raw hashes ($5\text{ compressions} \times 7\text{ encryptions} \times 2\text{ signs}$) and computing obfuscated tag tables per saved profile.
  - Pre-flight collision checks against built-in and existing custom tags before saving or importing.
  - Automatic fallback custom map picker dialog during auto-decryption when receiving messages using an unindexed custom map.
- **Testing & Verification**:
  - Comprehensive unit test suite in `test/services/custom_map_test.dart` covering validation, serialization, duplicate detection, bundle export/import, tag routing, and full encryption/decryption roundtrips.
  - Regression assertions verifying the 840 built-in routing tags remain unchanged and collision-free.

### Changed
- Migrated obfuscation pipeline to `obfuscate ^1.0.1` with strict v2 wire formats (`en1v2`, `en2v2`, `fa1v2`, `fa2v2`).
- Encrypt mode automatically coerces legacy obfuscation selections to their v2 equivalents while keeping legacy decoders intact for historical messages.
- Updated settings fallback to guarantee `custom` is never selected as a default preset.

---

## [5.1.0] - 2026-10-31

### Added
- Comprehensive test matrix covering 200 full symmetric and RSA encryption-decryption roundtrip combinations.
- Coercion of legacy obfuscation methods to v2 equivalents on encryption.

### Fixed
- Fixed custom AES key input field visibility, icon placement, and preset label alignment in `EncryptionPage`.
- Resolved `DropdownButtonFormField` layout overflow in `CreateAESKeyDialog` on narrow screen widths.

---

## [5.0.0] - 2026-10-30

### Security
- **User-Managed AES Keys**: Removed `flutter_dotenv` and static default AES keys. All AES keys are now strictly user-managed and stored in platform-native secure storage (`FlutterSecureStorage`).
- **Cryptographic IV Randomness**: Migrated AES-CBC and AES-CTR to use cryptographically secure random IVs (`Random.secure()`), eliminating static/reused IV vulnerabilities.
- **Fail-Closed ML-DSA Verification**: Hardened ML-DSA signature verification so missing keys or altered signatures fail closed immediately without executing the decryption pipeline.
- **Compression Hardening**: Added input and ratio guards against decompression bomb attacks across gzip, lz4, brotli, and zstd.

### Added
- Comprehensive RSA key generation, OAEP encryption, PSS signing, and hybrid envelope test suites.
- Decrypt-only golden vector compatibility suite verifying deterministic recovery of legacy ciphertexts.
- Android 16 KB page-size native library alignment.

---

## [4.7.0] - 2026-10-20

### Added
- Post-quantum cryptography integration via `liboqs` (ML-KEM key encapsulation and ML-DSA digital signatures).
- Automatic tag routing system identifying algorithm combinations from message headers.
- Multi-algorithm compression support (Gzip, LZ4, Brotli, Zstandard).
