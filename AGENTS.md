# Repository Guidelines

## Project Structure & Module Organization
`qrypt` is a Flutter app with platform targets in `android/`, `ios/`, `linux/`, `macos/`, `windows/`, and `web/`. Core app code lives in `lib/`:
- `lib/pages/` UI screens and page-level widgets
- `lib/services/` crypto/compression/obfuscation and key-management logic
- `lib/providers/` Riverpod state wiring
- `lib/models/` domain models
- `lib/resources/` shared constants/resources

Tests currently live in `test/` (see `test/widget_test.dart`). Static assets are under `assets/` and native runtime libraries under `native_libs/` and platform `jniLibs` folders.

## Build, Test, and Development Commands
Run from the repository root:
- `flutter pub get` installs dependencies
- `flutter run -d <device>` runs locally (example: `flutter run -d linux`)
- `flutter analyze` runs Dart/Flutter static analysis
- `dart analyze` equivalent analyzer check for CI/local scripts
- `flutter test` runs the test suite
- `flutter test --coverage` generates coverage data in `coverage/`
- `dart run build_runner build --delete-conflicting-outputs` regenerates Riverpod/codegen outputs when annotations change

## Coding Style & Naming Conventions
Follow `analysis_options.yaml` (`flutter_lints`). Use 2-space indentation and format with `dart format .` before submitting. Prefer:
- `snake_case.dart` file names
- `UpperCamelCase` for classes/types
- `lowerCamelCase` for methods/variables

Keep widgets focused and move crypto/business logic into `lib/services/` rather than UI files.

## Testing Guidelines
Use `flutter_test` for widget/unit tests. Name files `*_test.dart` and colocate by feature under `test/` (for example, `test/services/aes_encryption_test.dart`). Add tests for any changed crypto pipeline, key handling, or parsing/tag behavior; prioritize deterministic test vectors over random-only assertions.

## Commit & Pull Request Guidelines
Recent history contains many generic messages (for example `lazyCommit`); prefer clear, imperative commits instead, such as `feat(ml-dsa): validate signature length` or `fix(rsa): handle malformed PEM import`.

PRs should include:
- concise summary and motivation
- linked issue (if applicable)
- test evidence (`flutter test`, `flutter analyze`)
- screenshots/GIFs for UI changes
- notes about platform-specific impact (Android/iOS/Desktop/Web)

## Security & Configuration Tips
Never commit secrets. Keep `.env` local; use `.env.example` as the template for required keys.

Obfuscation maps are now code-defined and user-overridable:
- built-in maps live in `lib/resources/obfuscation/built_in_obfuscation_maps.dart`
- runtime resolution/custom overrides go through `lib/services/obfuscation/obfuscation_map_repository.dart`

When editing encryption UX, preserve user-facing warnings for insecure defaults:
- warn when AES uses the app default key instead of a custom key
- warn when both encryption and obfuscation are `NONE` (output falls back to Base64)

Also keep default-mode behavior and visible advanced selections aligned. If default mode uses `AES-GCM + GZip + EN2 + tag`, switching to manual mode should prefill the same values.
