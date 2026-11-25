# Qrypt — Project Context for Gemini / Antigravity

Supplement to `AGENTS.md` capturing key architecture, UX invariants, testing quirks, and release workflow details.

## UI Architecture & Recent Refactors (`v5.8.1`)
- **Main Screen (`lib/pages/encryption_page.dart`)**:
  - Top header bar houses Key Management button, `modeSwitch` (`lib/pages/widgets/mode_switch.dart`), and Settings button.
  - Horizontal swipe-to-switch (`_onSwipeLeft` / `_onSwipeRight`) is intentionally scoped to the top header bar so horizontal text-selection drags in Input/Output fields do not toggle modes.
  - `Encapsulate & Encrypt`, `Encrypt`, and `Decrypt` button labels use `Flexible` + ellipsis (`maxLines: 1`) and `modeSwitch` uses `FittedBox(fit: BoxFit.scaleDown)` to prevent horizontal RenderFlex overflow on narrow screens (`320px+`) and large text scales.
- **Dedicated Output Panel (`lib/pages/widgets/encryption_output_panel.dart`)**:
  - `EncryptionOutputPanel` renders the divider, optional `MLKemSharedSecretCard`, section header (Clear, Ciphertext QR Share in Encrypt mode, Copy), `DecryptPipelineSummary` (signature verification status + detected `encryption • compression • obfuscation` pill), and scrollable `SelectableText` output box.
  - Tap handlers read `processedEncryptProvider` / `processedDecryptProvider` lazily via `ref.read(...)` so in-place `.text` updates work consistently alongside state updates.
  - Copy passes `isSensitive: !isEncryptMode` so only decrypted plaintext (never ciphertexts, public keys, or obfuscation maps) activates `ClipboardSecurityService` (60s auto-clear + Android `EXTRA_IS_SENSITIVE`).
- **Public Key QR Sharing (`lib/pages/widgets/asymmetric_selector_header.dart`, `lib/pages/widgets/qr/qr_share_dialog.dart`)**:
  - `AsymmetricSelectorHeader` + `resolveSelectedKeyPair<T>` provide the 1-tap `Icons.qr_code_2` public-key share button (with active key name tooltip) across `RSAKeySelector`, `KemKeySelector`, and `MlDsaKeySelector`, hidden when empty/loading. Symmetric `AESKeySelector` must never expose QR/share shortcuts.
  - `PublicKeyShareCard`, `PublicKeyShareRow`, and `showPublicKeyChoiceDialog<T>` render the expandable/retractable (`initiallyExpanded: false`) public-key shortcut card in `EncryptionPage` for Manual Encrypt (`mlKem` / `rsa`) and Auto-Detect Decrypt (`RSA` / `ML-KEM` / `ML-DSA`), syncing active selections with `selectedRSADecryptKeyPairProvider`, `selectedKemDecryptKeyPairProvider`, and `selectedMlDsaSignKeyPairProvider`.
  - `QrShareDialog` enforces `QrPayloadKind` (`publicKey`, `ciphertext`, `obfuscationMap`), wraps titles up to 2 lines so key names do not truncate, and falls back from ECC Level M to Level L for dense post-quantum keys.

## Native Crypto & Platform Notes
- Post-quantum KEM/DSA uses `package:oqs` backed by `liboqs-0.16.0` loaded via `OqsLoader` (`lib/services/oqs_loader_io.dart` on native, stubbed on Web).
- Android release manifest (`android/app/src/main/AndroidManifest.xml`) disables backups (`android:allowBackup="false"`, `android:fullBackupContent="false"`, `dataExtractionRules`) and omits `INTERNET` permission.

## Testing & Analyzer Gotchas
- Prefer `flutter analyze --no-pub --no-fatal-infos lib/ test/` and `flutter test --no-pub` to avoid slow dependency resolution or spurious `pubspec.lock` / `android/.../GeneratedPluginRegistrant.java` diffs.
- Note that `Dropdown_button_forms.dart` currently uses `DropdownButtonFormField` without `isExpanded: true`; keep layout tests targeting full `EncryptionPage` (`Ahem` font) at `>=400px` unless those dropdowns are updated too, and test `modeSwitch` directly down to `320px`.
- In Riverpod widget tests, give any re-pumped `ProviderScope` with different overrides a distinct `Key` (e.g. `ValueKey`) so `ProviderContainer.updateOverrides` does not assert on override-count changes.
- In `testWidgets` that trigger sensitive clipboard writes (`isSensitive: true`), call `ClipboardSecurityService.cancelPendingClear()` at the end of the test body (before teardown) so FakeAsync's `!timersPending` check succeeds.

## Release Workflow (`.github/workflows/release.yml`)
- Pushing a `v*` tag runs `verify` (`flutter analyze --no-fatal-infos --no-fatal-warnings` + `flutter test`), then builds versioned artifacts across:
  - **Android** (`arm64-v8a`, `armeabi-v7a`, `x86_64` split APKs + `.aab`; requires `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` secrets on tag builds).
  - **Linux** (`.tar.gz`, `.deb`, `.rpm` bundling `liboqs.so`).
  - **macOS** (`.zip` bundling `liboqs.dylib` + ad-hoc `codesign` re-seal of `liboqs.dylib` and the `.app` with `macos/Runner/Release.entitlements`).
  - **Windows** (portable `.zip` with `oqs.dll` + Inno Setup `.exe`).
- Outputs `qrypt-v<version>-SHA256SUMS.txt` and creates a **draft** GitHub Release by default.
- Before tagging `vX.Y.Z`, update `version:` in `pubspec.yaml`, add a `## [X.Y.Z]` section in `CHANGELOG.md`, and keep `web/manifest.json` metadata accurate.
