# Repository Guidelines

## Architecture & Code Organization
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
Never commit secrets. AES keys are user-managed and stored in platform-native secure storage (`FlutterSecureStorage`). No static default key or `.env` file is used.

Obfuscation maps are now code-defined and user-overridable:
- built-in maps live in `lib/resources/obfuscation/built_in_obfuscation_maps.dart`
- runtime resolution/custom overrides go through `lib/services/obfuscation/obfuscation_map_repository.dart`

When editing encryption UX, preserve security guards:
- warn when both encryption and obfuscation are `NONE` (output falls back to Base64)

Also keep default-mode behavior and visible advanced selections aligned. If default mode uses `AES-GCM + GZip + EN2 + tag`, switching to manual mode should prefill the same values.
