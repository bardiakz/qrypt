# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.8.0] - 2026-11-25

### Added
- **Direct Public Key QR Sharing Shortcuts (Asymmetric Algorithms)**:
  - Added a 1-tap **Share Public Key** QR shortcut (`Icons.qr_code_2`) in the header of asymmetric key selector cards (`RSAKeySelector`, `KemKeySelector`, `MlDsaKeySelector`) with key-pair name tooltips, automatically hidden when no key pair is available (keeping symmetric `AESKeySelector` strictly excluded).
  - Added an expandable/retractable **Public Key Share Card** (`PublicKeyShareCard`) to `EncryptionPage` (retracted by default with summary labels):
    - **Auto-Detect Decrypt mode**: Displays aligned rows for algorithms with saved key pairs (`RSA`, `ML-KEM`, `ML-DSA`), lets users switch the active key pair via `showPublicKeyChoiceDialog` (synced with the active decrypt/sign key providers and featuring a `Manage Keys` action), and shares the chosen public key via QR/clipboard in 1 tap.
    - **Manual Encrypt mode (`ML-KEM` / `RSA`)**: Lets users inspect, switch, or create their own key pair directly below the recipient public key field and share its public key via QR without leaving the Encryption page.
  - Updated `QrShareDialog` titles to support up to 2 lines so full key pair names stay readable without truncation.

## [5.7.3] - 2026-11-25

### UI & UX Improvements
- **Dark Mode Contrast & Theme Consistency**:
  - Fixed Dark Mode contrast across Settings Danger Zone, Key Management Security Notice and accent icons (`colorScheme.primary`), the Encrypt/Decrypt mode switch track, and key selector/dialog borders.
- **Scrollable Output, Clear Output & Decrypt Verification Summary**:
  - Made the Output box scrollable (`SingleChildScrollView`), added empty-state placeholder hints, and added a one-tap **Clear Output** action (`Icons.clear_all`) that also resets ephemeral ML-KEM shared secret and decrypt metadata state.
  - Added a Decrypt pipeline & signature verification summary strip (`Signature Verified (ML-DSA / RSA-PSS / RSA Legacy)` vs `Unsigned` plus detected algorithm/compression/obfuscation) that clears immediately on input edit, clear, or decryption failure.
  - Added a non-intrusive active AES key indicator chip in Auto-Detect Decrypt mode that preserves the smart active-key / last-used fallback while letting users switch keys before decrypting.
- **Desktop/Web Ergonomics & Input Polish**:
  - Added scrollbar-safe centered max-width (`840px`) padding on Encryption, Settings, and Key Management screens while keeping mobile viewports (`<360px`) overflow-free.
  - Restricted the horizontal swipe-to-switch-mode gesture to the top header bar so text selection in Input/Output fields never accidentally toggles modes.
  - Fixed live validation on the Custom AES Key field, moved the public key Paste button to `suffixIcon` so it never overlaps pasted keys, added dropdown overflow protection (`isExpanded` + ellipsis), updated header icons/tooltips (`Key Management`, `Settings`, `Ctrl+M`), standardized `ML-KEM (Kyber)` and Settings Clear Data copy, and formatted character counters with units (`chars`).

## [5.7.2] - 2026-11-22

### Security
- **ML-DSA Manual Import Validation & Multi-Parameter Set Support**:
  - Fixed inverted `validateKeyPair` condition in `CreateMlDsaKeyDialog`, wired the selected parameter set (`ML-DSA-44`, `ML-DSA-65`, `ML-DSA-87`, defaulting to `ML-DSA-65`) into a scoped and properly disposed `MlDsaKeyService`, fixed `generateKeyPair` argument handling, and scoped manual Base64 decoding with explicit `FormatException` handling.
  - Replaced hardcoded `ML-DSA-65` usage across `MlDsaKeyService` and `InputHandler` with automatic parameter-set detection from public/secret key byte lengths (`1312`/`2560`, `1952`/`4032`, `2592`/`4896`), exact pre-call length validation, per-key algorithm dispatch for stored keys, and deterministic native `dispose()` cleanup in `finally` blocks.
- **Headless Signature Verification Fail-Closed**:
  - Removed `context != null` gating around signature verification in both tagged and untagged `InputHandler.handleDeProcess` paths so signature verification always runs fail-closed regardless of UI context availability.
  - Made `BuildContext?` optional in `handleVerify` (gating only snackbar UI notifications) and replaced silent early returns on unmounted contexts with explicit cancellation exceptions.
- **RSA-OAEP Base64-Aware Payload Guard & 2048-Bit Floor**:
  - Corrected `InputHandler`'s pre-encryption RSA payload limit to account for Base64 expansion inside OAEP-SHA256 (`141` bytes for 2048-bit, `237` for 3072-bit, `333` for 4096-bit) while preserving full v5.x wire compatibility.
  - Enforced a minimum 2048-bit RSA modulus (`RSAKeyService.minKeyBits`) on key generation, import, validation, and encryption while keeping decryption and verification permissive for legacy keys.
- **Prevent Silent Keystore Wipes on Read/Parse Errors**:
  - Hardened AES, RSA, ML-KEM, ML-DSA, and custom obfuscation storage services (`AesKeyStorageService`, `RSAKeyStorageService`, `KemKeyStorageService`, `MlDsaKeyStorageService`, `ObfuscationMapRepository`, and `CustomMapStorageService`) to use strict read paths before mutating storage, failing closed instead of overwriting existing keys or profiles when transient keyring or JSON parse errors occur.
- **Full-Entropy Random AES Key Generation (128 / 192 / 256-bit)**:
  - Upgraded `generateRandomAesKey()` to generate full cryptographically random raw key bytes (8 bits/byte via `Random.secure()`) across all key sizes instead of 6-bit/char ASCII strings (which previously yielded 96 / 144 / 192 bits of entropy):
    - **AES-128** (16 raw bytes) → `24`-char Base64 (ends with `==`).
    - **AES-192** (24 raw bytes) → `48`-char Hex (avoids colliding with legacy 32-byte UTF-8 AES-256 keys).
    - **AES-256** (32 raw bytes) → `44`-char Base64 (ends with `=`).
  - *Backward Compatibility Note*: All previously created 16/24/32-character UTF-8 keys continue to decrypt and validate identically. Newly generated **256-bit** keys (`44`-char Base64) are 100% compatible with older v5.x builds; newly generated **128-bit** (`24`-char Base64) and **192-bit** (`48`-char Hex) keys require Qrypt `5.7.2+` on the recipient side.
- **Hardened Secure Storage Configuration (`flutter_secure_storage` `11.2.0`)**:
  - Upgraded `flutter_secure_storage` from `^10.0.0` (`10.3.4`) to `^11.2.0`, picking up hardened Android KeyStore ciphers (removal of legacy PKCS#1/CBC/EncryptedSharedPreferences paths), Linux fail-closed orphaned keyring handling, and Darwin cross-accessibility Keychain lookup fixes.
  - Centralized all storage services onto `qryptSecureStorage` (`lib/services/secure_storage_config.dart`) with Android `resetOnError: false` (preventing silent keystore wipes on transient KeyStore errors) and iOS/macOS `KeychainAccessibility.unlocked_this_device` with `synchronizable: false` (hardware-bound, excluded from backups and iCloud Keychain sync).
- **Android Platform Hardening & Configurable Screen Protection (`FLAG_SECURE`)**:
  - Removed the unnecessary `android.permission.INTERNET` permission from the release `AndroidManifest.xml` (retained in debug manifests only) and disabled Android Auto Backup / device transfers (`android:allowBackup="false"`, `android:fullBackupContent="false"`, and `android:dataExtractionRules="@xml/data_extraction_rules"`).
  - Added an Android `FLAG_SECURE` platform channel (`ScreenSecurityService`) and a **Settings → Security → Block Screenshots & Screen Recording** toggle (enabled by default on Android, persisted across restarts) so users can control screenshot, screen-recording, and recents-screen protection.
- **Unencrypted Output Warning & Shoulder-Surfing Protections**:
  - Added a clear warning banner in manual mode whenever `Encryption: None` is selected alongside an obfuscation method, clarifying that obfuscation does not provide cryptographic confidentiality (while preserving the existing Base64 fallback warning when both encryption and obfuscation are `None`).
  - Hid RSA private keys and ML-KEM/ML-DSA secret keys by default behind an explicit **Reveal Private/Secret Key** toggle in key export dialogs (keeping QR codes strictly limited to public keys), and obscured manual secret key inputs by default with visibility toggle buttons across AES, RSA, ML-KEM, and ML-DSA key creation dialogs.
- **Configurable Sensitive Clipboard Protection**:
  - Added `ClipboardSecurityService` and a **Settings → Security → Protect Sensitive Clipboard** toggle (enabled by default) scoped strictly to **secret keys** and **decrypted plaintext** (never ciphertexts, public keys, or obfuscation maps).
  - Marks sensitive copies with Android `ClipDescription.EXTRA_IS_SENSITIVE` (Android 13+ / compat extra on older Android) and schedules a 60-second auto-clear timer that clears the clipboard only if it still holds the copied secret.
- **Flutter Web Hardening & Desktop Native Loader Cleanup**:
  - Upgraded `Compression.gZipDeCompress` on Flutter Web (`lib/services/compression_web.dart`) to use streaming `maxOutputSize` inflation via `package:archive`, aborting decompression bombs immediately during decoding rather than buffering the full output in memory first.
  - Added a dismissible Flutter Web storage notice clarifying that browser storage is not hardware-backed Keystore/Keychain storage.
  - Gated the final relative `'liboqs-0.16.0'` fallback in `lib/services/oqs_loader_io.dart` behind `kDebugMode || FLUTTER_TEST` so release desktop builds strictly load native libraries relative to `Platform.resolvedExecutable`.
- **Release Logging Hygiene & Dead Code Removal**:
  - Removed unused `lib/services/pqc.dart` and guarded all remaining diagnostic logs in `lib/` behind `kDebugMode` / `debugPrint`.
- **Unpredictable ML-KEM Key Identifiers**:
  - Replaced predictable timestamp-based IDs in `QryptKEMKeyPair` with `Uuid().v4()`.

### Fixed
- **RSA PEM Normalization**:
  - Fixed `RSAKeyService.normalizePem` footer filtering (`!line.startsWith('-----END')`) and added empty/invalid Base64 body rejection.
- **Encryption Page Mode Alignment & Null Safety**:
  - Aligned default-mode encryption to `SignMethod.none`, reset `selectedSignProvider` when switching to manual mode, replaced an unsafe `!` null-unwrap on RSA decrypt key selection with a clean null check, and validated manual ML-DSA verification key Base64 decoding.
- **Idempotent Linux Desktop Integration Tests**:
  - Updated `integration_test/desktop_codecs_test.dart` to use in-memory KEM/ML-DSA storage doubles and deterministic `dispose()` cleanup so desktop integration tests never mutate or collide with the host OS keyring.

## [5.7.1] - 2026-11-21

### Fixed
- **Linux Desktop Native Codec Isolation & Symbol Collision (`-Wl,-Bsymbolic`)**:
  - Rebuilt Google Brotli `v1.2.1` statically into `native_libs/esbrotli-linux64.so` with `-Wl,-Bsymbolic`, eliminating ELF symbol preemption and struct layout divergence with host GTK3/FreeType libraries (`/lib64/libbrotlidec.so.1`).
  - Rebuilt LZ4 `v1.9.4` (`eslz4-linux64.so`) and Zstandard `v1.5.6` (`eszstd-linux64.so`) statically with `-Wl,-Bsymbolic` to preemptively prevent collision risks on distros linking `liblz4.so.1` or `libzstd.so.1` via Mesa drivers, `libsystemd`, `gdk-pixbuf` (`libtiff`), or `libsecret`.
  - Audited all native libraries: all `.so` binaries now declare `DT_SYMBOLIC`, depend only on `libc.so.6`/`libm.so.6`, and maintain a low GLIBC version floor (GLIBC 2.14 / 2.29).
- **Desktop GTK Integration Testing**:
  - Added `integration_test/desktop_codecs_test.dart` running in the real Linux desktop GTK runner (`flutter test integration_test -d linux`) verifying live end-to-end roundtrips for Brotli, LZ4, Zstd, ML-KEM, and ML-DSA.
- **Streaming Decompression Bounded Decoding**:
  - Updated `_decodeBounded` in `lib/services/compression.dart` to use `conversionSink.addSlice(..., isLast: true)` without redundant double-close for `ByteConversionSink`.
  - Placed `isClosed = true` safely after `addSlice` to ensure mid-stream exceptions (`DecompressionBombException`) correctly trigger native handle cleanup in `finally`.
  - Hardened `Compression.setNativeLibPaths()` to require all three dynamic libraries (`eslz4`, `esbrotli`, `eszstd`) in candidate directories.
- **Decompression vs UTF-8 Error Scope Separation**:
  - Separated decompression and UTF-8 decoding into distinct try/catch blocks in `InputHandler.handleDeCompression`. Added contextual diagnostics distinguishing authenticated AEAD (AES-GCM) decoder failures from corrupted payload or key mismatches.
- **Custom Map Dialog Lifecycle & Overflow**:
  - Extracted `_GenerateRandomMapDialog`, `_ImportCustomMapDialog`, and `_ImportMapForPickerDialog` to dedicated `StatefulWidget`s, properly disposing controllers to fix `_dependents.isEmpty: is not true` and controller disposal assertions on route dismiss.
  - Added `isExpanded: true` and text truncation to `DropdownButtonFormField` in `settings_page.dart` to eliminate horizontal `RenderFlex` overflows on long character pool names (e.g., `Hiragana Characters (58 chars)`).
- **Decryption Input Sanitization**:
  - Sanitized input text in `EncryptionPage._decrypt` with `.trim()` across both manual and tagged modes to prevent clipboard trailing whitespace and newlines from shifting token boundaries.

## [5.7.0] - 2026-11-19

### Added
- **Multi-Size Post-Quantum ML-KEM Support (NIST FIPS 203)**:
  - Added user selection for ML-KEM parameter sets across all standard security categories: `ML-KEM-512` (Category 1), `ML-KEM-768` (Category 3, Recommended), and `ML-KEM-1024` (Category 5).
  - Adaptive encapsulation and decapsulation pipelines in `KemKeyService` that detect key lengths automatically without altering UX flow.
  - Fail-fast parameter size validation on decapsulation preventing cryptographic format crashes when decrypting with mismatched key sizes.
  - Parameter set badges displayed on ML-KEM key cards and dropdown selectors.
- **Interactive QR Code Zoom & Fullscreen Viewer**:
  - In-dialog size toggle expanding modal width up to 520px and scaling QR matrix canvas up to 420px (~3.3x module area expansion) to dramatically enhance scan reliability for dense post-quantum keys.
  - Fullscreen pinch-to-zoom interactive viewer using `InteractiveViewer` with smooth pan, touch gestures, and desktop keyboard/mouse control buttons (Zoom In, Zoom Out, Reset Zoom).
- **Expanded Custom Obfuscation Pools**:
  - Added Armenian, Georgian, and Hiragana character pools to the custom map generator dialog.

### Fixed
- **Custom Map Generator Lifecycle & Crash Fixes**:
  - Resolved unhandled `FlutterError` exceptions during map generation and import by properly referencing the parent `ScaffoldMessenger` and verifying widget tree mounting before calling `pop()` or updating dialog state.
  - Implemented `operator ==` and `hashCode` on `CustomObfuscationProfile` based on profile ID, eliminating Flutter assertion crashes in `DropdownButtonFormField` when refreshing or reloading saved custom maps.
  - Implemented smart, pool-aware default map naming (e.g., `"English Words Map 1"`, `"Persian Words Map 1"`) to prevent duplicate naming ambiguity.
  - Synced selected custom map provider safely when profiles are deleted or updated.

## [5.6.0] - 2026-11-19

### Security
- **Odd-Nibble Hex Validation (SEC-08)**:
  - Enforced strict even-length validation in `Aes.fromHex` across AES-CBC, AES-CTR, and AES-GCM decoders. Truncated or corrupt hex inputs now fail fast with an explicit `FormatException` instead of silently dropping the trailing 4 bits.
- **Dependency Pinning (SEC-11)**:
  - Pinned unconstrained `any` dependencies in `pubspec.yaml` (`es_compression: ^2.0.16`, `path: ^1.9.1`, `crypto: ^3.0.8`) to guarantee deterministic CI builds.
- **Eliminate Untrusted CWD Library Search Path (SEC-03)**:
  - Guarded CWD fallback in `Compression.setNativeLibPaths()` and `OqsLoader` with debug/test mode checks, preventing DLL/SO hijacking in release distributions.
- **RSASSA-PSS Migration (SEC-06)**:
  - Migrated `SignMethod.rsaPss` from legacy EMSA-PKCS1-v1_5 to genuine RSASSA-PSS (SHA-256 with 32-byte salt, MGF1-SHA256, and secure entropy via Fortuna).
  - *Backward Compatibility Notice*: Digital signatures created in versions &le; 5.4.1 used PKCS#1 v1.5 and will not verify under 5.6.0+. Verification error messages explicitly advise that the signature may have originated from an earlier Qrypt release.
- **Streaming Decompression Bomb Protection (SEC-07)**:
  - Added a strict 25 MB safety expansion ceiling across all four decompressors (`GZip`, `LZ4`, `Brotli`, `Zstandard`) via `_decodeBounded` and zero-copy `BoundedByteSink`. Payloads exceeding 25 MB abort immediately with a clear `FormatException`, preventing Out-of-Memory crashes and UI freezing.
- **PKCS#8 RSA Private Key Serialization Fix**:
  - Corrected public exponent encoding in `_encodePrivateKeyToPem` (was previously serializing the private exponent $d$ in the public exponent position due to PointyCastle inheritance properties). Exported private keys are now strictly standard-compliant with OpenSSL and external cryptographic tools.

### Added
- **Air-Gapped QR Code Sharing (Public Keys & Ciphertexts Only)**:
  - Added QR code sharing strictly for public keys (RSA public keys, ML-KEM encapsulation keys, and ML-DSA verification keys) and encrypt-mode ciphertexts.
  - Omitted QR code display for private/secret credentials (RSA private keys, ML-KEM secret keys, ML-DSA secret keys, AES symmetric keys, and negotiated shared secrets) as a defensive measure against optical exfiltration until multiplatform biometric/app lock gating is available.
  - Restricted main screen QR export to encrypt-mode ciphertext only, preventing visual exposure of decrypted plaintext.
  - Implemented type-safe `QrPayloadKind` (`publicKey`, `ciphertext`, `obfuscationMap`) in `QrShareDialog` with automatic size limits ("Too large for a QR code. Use Copy."), density warnings (> 1,200 chars), and obfuscation map security advisories.
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

### Fixed
- **QR Code Matrix Capacity Validation for Oversized Payloads**:
  - Eagerly evaluates QR code matrix generation via `QrImage(qr)` to catch `InputTooLongException` before rendering. Prevents red-screen UI crashes when sharing oversized keys (such as ML-DSA-65 verification keys exceeding the 18,672-bit Version 40 Level M capacity limit) and displays a clean fallback card ("Too large for a QR code. Use Copy.") while suppressing misleading density warnings.

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
