# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.3.1] - 2026-11-04

### Fixed
- **AES-CBC & AES-CTR Decryption Key Synchronization**:
  - Synchronized active encryption AES key and last-used key to the decryption pipeline so AES-CBC and AES-CTR ciphertexts decrypt seamlessly in single-tap auto-tag mode without spurious `MissingKeyException` cancellations.
  - Initialized `selectedAESDecryptKeyProvider` on app launch and updated it on successful encryption when unset.
  - Upgraded `_showCustomKeyDialog` to automatically pre-select and pre-fill the last-used key (or single saved key), enabling immediate decryption.
  - Updated custom key dialog validation and `ElevatedButton.onPressed` to accept 44-character Base64 and 64-character Hex 256-bit AES keys via `validateAesKey()` instead of strictly enforcing 16/24/32 raw ASCII character counts.
  - Persisted `lastUsedKeyId` upon successful manual key entry decryption in `InputHandler`.
  - Added full test suite in `test/services/aes_cbc_ctr_dialog_and_decrypt_test.dart` verifying CBC/CTR direct decryption, dialog pre-selection, manual hex key entry, and cancellation behavior.

---

## [5.3.0] - 2026-11-04

### Added
- **ML-KEM Pipeline Integration**:
  - Integrated NIST ML-KEM-768 (FIPS 203) / Kyber-768 directly into the standard Qrypt encryption/decryption pipeline (`handleProcess` and `handleDeProcess`).
  - Added `Qrypt.withKem(...)` constructor for encapsulation against recipient public keys.
  - TagManager routing support: ML-KEM wire payloads now include standard 6-character routing tags, enabling automatic algorithm detection on decryption without triggering custom map fallbacks.
  - Seamless post-quantum hybrid composition: ML-KEM payloads can be signed with ML-DSA and obfuscated with built-in or custom maps.
  - Automatic prompt (`showKemKeySelectionDialog`) during auto-decryption when the recipient private key is needed.
- **Prefix-Free Transparent Key Validation & Parsing**:
  - Transparently accepts 16, 24, and 32-character UTF-8 text keys, 44-character Base64 keys, and 64-character Hexadecimal keys across `validateAesKey()`, `parseAesKey()`, and `AESKey` models without requiring non-standard prefixes.
  - Updated `AESKey.byteLength` and `bitLength` to recognize 44-char Base64 and 64-char Hex representations as 32-byte / 256-bit AES keys.
- **Shared Secret UI & Conversion**:
  - Added `MLKemSharedSecretCard` in output view with format toggle between Base64 (44 chars) and Hex (64 chars).
  - One-tap "Save as AES Key" button pre-filling `CreateAESKeyDialog` for immediate persistence.
  - Prominent warning banner for senders advising that the freshly encapsulated secret is ephemeral and must be saved immediately.
- **Pipeline Guards**:
  - Automatically locked compression to `CompressionMethod.none` in constructors and UI for ML-KEM, preventing futile compression on high-entropy cryptographic bytes.
- **Testing**:
  - Comprehensive unit and roundtrip test suite in `test/services/ml_kem_pipeline_test.dart` verifying key validation, parsing, model invariants, full obfuscation permutations, and immediate AES-GCM encryption with derived shared secrets.

### Fixed
- Fixed reactive mode switching so the ML-KEM info container immediately unmounts when changing the encryption algorithm away from ML-KEM.
- Resolved UI bug where the ephemeral "Save this secret now" banner and shared secret card lingered after switching to AES or other encryption algorithms.
- Added automatic state listeners and pipeline guards to clear ephemeral KEM shared secret state on algorithm changes, swipe mode switches, and non-KEM encryption/decryption operations.

---

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
