# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.5.0] - 2026-11-18

### Security
- **Odd-Nibble Hex Validation (SEC-08)**:
  - Enforced strict even-length validation in `Aes.fromHex` across AES-CBC, AES-CTR, and AES-GCM decoders. Truncated or corrupt hex inputs now fail fast with an explicit `FormatException` instead of silently dropping the trailing 4 bits.
- **Dependency Pinning (SEC-11)**:
  - Pinned unconstrained `any` dependencies in `pubspec.yaml` (`es_compression: ^2.0.16`, `path: ^1.9.1`, `crypto: ^3.0.8`) to guarantee deterministic CI builds.
- **Eliminate Untrusted CWD Library Search Path (SEC-03)**:
  - Guarded CWD fallback in `Compression.setNativeLibPaths()` and `OqsLoader` with debug/test mode checks, preventing DLL/SO hijacking in release distributions.
- **RSASSA-PSS Migration (SEC-06)**:
  - Migrated `SignMethod.rsaPss` from legacy EMSA-PKCS1-v1_5 to genuine RSASSA-PSS (SHA-256 with 32-byte salt, MGF1-SHA256, and secure entropy via Fortuna).
  - *Backward Compatibility Notice*: Digital signatures created in versions &le; 5.4.1 used PKCS#1 v1.5 and will not verify under 5.5.0+. Verification error messages explicitly advise that the signature may have originated from an earlier Qrypt release.
- **Streaming Decompression Bomb Protection (SEC-07)**:
  - Added a strict 25 MB safety expansion ceiling across all four decompressors (`GZip`, `LZ4`, `Brotli`, `Zstandard`) via `_decodeBounded` and zero-copy `BoundedByteSink`. Payloads exceeding 25 MB abort immediately with a clear `FormatException`, preventing Out-of-Memory crashes and UI freezing.
- **PKCS#8 RSA Private Key Serialization Fix**:
  - Corrected public exponent encoding in `_encodePrivateKeyToPem` (was previously serializing the private exponent $d$ in the public exponent position due to PointyCastle inheritance properties). Exported private keys are now strictly standard-compliant with OpenSSL and external cryptographic tools.

### Added
- **Air-Gapped QR Code Sharing**:
  - Added a dedicated QR code export action in the Output section header on `EncryptionPage` to share ciphertexts or decrypted text directly to mobile devices without network connectivity.
  - Added QR code sharing across all cryptographic key dialogs: AES symmetric keys, RSA public/private keys, ML-KEM (Kyber) public keys and negotiated shared secrets, and ML-DSA (Dilithium) verification keys.
  - Unified all QR code displays under a contrast-isolated, auto-sizing `QrShareDialog` with payload density advisories and oversized payload protections.
- **Desktop Keyboard Shortcuts**:
  - `Ctrl+Enter` / `Cmd+Enter`: Trigger encryption or decryption processing.
  - `Ctrl+M` / `Cmd+M`: Quickly toggle between Encrypt and Decrypt modes.
  - `Ctrl+Shift+C` / `Cmd+Shift+C`: Copy the processed output to the clipboard.
  - `Ctrl+L` / `Cmd+L`: Clear the current input text field and reset temporary session state.
- **Action Button Tooltips**:
  - Added descriptive `Tooltip` widgets to primary actions (Clear, Paste, Copy, Process) displaying their functionality and keyboard shortcuts.
- **First-Launch Disclaimer & Legal Terms**:
  - Added a non-dismissible first-time `DisclaimerDialog` requiring explicit user acknowledgement (`I Understand & Accept`) before using the app.
  - Persisted acceptance state in secure storage (`SettingsStorageService`).
  - Added persistent access to the Disclaimer & Terms via **Settings > About**.
- **Explicit Backward Compatibility & Warranty Notices**:
  - Explicitly documents that while best efforts are made to preserve backward compatibility, backward compatibility across versions is **not guaranteed** across cryptographic library updates, algorithm evolutions, or tag format revisions.
  - Standard "AS IS" disclaimer of warranties and comprehensive limitation of liability protecting authors against claims of data loss or compromised keys.
- **Privacy Policy Revamp & In-App Synchronization**:
  - Fully updated `PRIVACY_POLICY.md` detailing 100% offline zero-telemetry architecture, local OS keystore security (`FlutterSecureStorage`), user data sovereignty, and unencrypted backup advisories.
  - Synchronized the in-app Settings Privacy Policy dialog with an option to view the full document online.

### Changed
- **Idiomatic Riverpod Invalidation**:
  - Replaced `ref.refresh()` calls with `ref.invalidate()` across key management and selection dialogs to avoid unhandled return value warnings.
- **Color Opacity Modernization**:
  - Updated deprecated `Color.withOpacity(...)` calls to modern `Color.withValues(alpha: ...)`.

---

## [5.4.1] - 2026-11-15

### Changed
- **Modernized `Qrypt` Model & Safe Defaults**:
  - Replaced fragile `late final` variables (`encryption`, `obfuscation`, `compression`) with safe default enum values (`.none`), permanently eliminating the risk of `LateInitializationError` during `Qrypt.autoDecrypt` or early property inspections.
  - Added `RSAKeyPair.empty` singleton constant, eliminating redundant heap allocations and `DateTime.now()` calls on every `Qrypt` instantiation.
  - Renamed typo `dsaVerifyPublicKEy` to standard camelCase `dsaVerifyPublicKey`, retaining a backward-compatible `@Deprecated` alias so existing integrations continue functioning seamlessly.
  - Optimized buffer initialization using `Uint8List(0)` and `const <int>[]` rather than allocating via `utf8.encode('')`.
  - Added dedicated unit test suite in `test/models/qrypt_model_test.dart` (594 tests passing).

---

## [5.4.0] - 2026-11-14

### Added
- **Orthogonal RSA-PSS Digital Signatures (`SignMethod.rsaPss`)**:
  - Decoupled RSA digital signatures from encryption modes by introducing `SignMethod.rsaPss` ("RSA-PSS (SHA-256)"), enabling RSA signatures to be composed orthogonally with any encryption cipher (AES-GCM, AES-CBC, AES-CTR, ML-KEM) or standalone plaintext.
  - Implemented standard **Encrypt-then-Sign** (EtS) pipeline ordering in `InputHandler`.
  - Added `RSASignKeySelector` widget for explicit signing key selection and `rsa_public_key_input_dialog.dart` for prompt-based recipient public key input during auto-tag verification.
  - Expanded `TagManager` and custom map tag combinations from 840 to 1,260 with 0 hash collisions.
- **Configurable RSA Key Sizes**:
  - Added user-selectable key size dropdown in `CreateRSAKeyDialog` supporting `2048`, `3072`, and `4096` bits, defaulting to `3072` bits for newly generated keys (aligned with NIST guidance).
  - Unlocked `RSAKeyService.generateKeyPair(keySize)` to respect caller-specified key sizes instead of hardcoding 2048 bits.
- **RSA Payload Size Guard**:
  - Added pre-encryption payload size guard in `InputHandler` enforcing maximum plaintext limits: `(keyBits ~/ 8) - 66` (e.g. 190 bytes for 2048-bit, 318 bytes for 3072-bit).
  - Throws typed `RsaPayloadTooLargeException` with actionable user guidance suggesting AES-GCM for larger payloads rather than crashing with unhandled cipher buffer errors.
- **Cross-Platform Packaging & Desktop Distribution**:
  - Added CI release workflows for building Linux `.deb`, `.rpm`, and Windows installers.
  - Added multi-resolution Linux application icons (16x16 to 512x512) and automatic desktop database and icon cache updates (`gtk-update-icon-cache`, `update-desktop-database`).

### Changed
- **RSA-OAEP-256 Padding Upgrade**:
  - Upgraded RSA-OAEP cipher padding to SHA-256 (`OAEPEncoding.withSHA256`) across encryption, decryption, and key validation routines.
  - Updated algorithm display name from `RSA-OAEP-SHA1` to `RSA-OAEP-256`.
- **Legacy `rsaSign` UI Deprecation**:
  - Flagged legacy bundled `EncryptionMethod.rsaSign` with `isUserSelectable = false` to hide it from manual encryption dropdowns while preserving full backward-compatibility for auto-decrypting legacy messages.
- **State Architecture & Scoped Riverpod Providers**:
  - Replaced mutable top-level globals (`decryptPublicKeyGlobal`, `verifyMlDsaPublicKeyGlobal`, `decryptKemPublicKeyGlobal`, `rsaVerifyPublicKeyGlobal`) with scoped Riverpod providers in `lib/providers/key_input_providers.dart`.
  - Removed state mutation anti-patterns from `EncryptionPage.build()`, migrating side-effects to `ref.listen` and `initState`.

### Fixed
- **Android Gradle Plugin & Gradle Alignment**:
  - Upgraded Android Gradle Plugin from `9.1.0` to `9.1.1` in `android/settings.gradle.kts` to meet Flutter's minimum AGP requirement.
  - Upgraded Gradle wrapper to `9.5.0` (`gradle-9.5.0-all.zip`) in `gradle-wrapper.properties` to clear Flutter Gradle deprecation warnings.
- **Fail-Closed Signature Verification**:
  - Hardened signature verification in the legacy `rsaSign` decode path so verification failures immediately throw `FormatException` and halt data return, eliminating a fail-open flaw.
  - Enforced strict fail-closed verification for `SignMethod.rsaPss`.
- **Settings Data Cleanup & Android Manifest**:
  - Comprehensive provider invalidation and custom obfuscation map cache reloading upon "Clear All Data" in `SettingsPage`.
  - Removed invalid activity action declaration from `AndroidManifest.xml`.

---

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
