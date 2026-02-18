liboqs - All Platforms Combined
================================

Structure:
  lib/x86_64/liboqs.so      - Linux x86_64
  lib/aarch64/liboqs.so     - Linux ARM64
  lib/liboqs.dylib          - macOS ARM64
  lib/cmake/                - CMake config
  bin/oqs.dll               - Windows x64
  include/oqs/              - Headers
  android/arm64-v8a/        - Android ARM64
  android/armeabi-v7a/      - Android ARM32
  android/x86_64/           - Android x86_64
  android/x86/              - Android x86
  liboqs.xcframework/       - iOS XCFramework

Usage with LibOQSLoader:
  LibOQSLoader.loadLibrary(binaryRoot: '/path/to/liboqs-VERSION');
