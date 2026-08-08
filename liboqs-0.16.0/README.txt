liboqs 0.16.0 - All Platforms Combined
===========================================

Every platform/architecture has its own subfolder so nothing collides:

  include/oqs/*.h              - headers (shared)
  linux/x86_64/liboqs.so*
  linux/aarch64/liboqs.so*
  macos/x86_64/liboqs.dylib
  macos/arm64/liboqs.dylib
  windows/x86_64/oqs.dll
  android/arm64-v8a/liboqs.so
  android/armeabi-v7a/liboqs.so
  android/x86_64/liboqs.so
  android/x86/liboqs.so
  ios/liboqs.xcframework/...

Desktop (Linux/macOS/Windows): point your loader at the path for
your platform directly, e.g. with oqs-dart's LibraryPaths.fromBinaryRoot().

Android: Flutter cannot dlopen() a shared library sitting outside the
app's native library directory. Copy android/<abi>/liboqs.so into
android/app/src/main/jniLibs/<abi>/liboqs.so in your Flutter project
yourself before building.

iOS: Flutter/iOS release builds require code-signed, embedded
frameworks. Add ios/liboqs.xcframework to your Xcode project under
"Frameworks, Libraries, and Embedded Content" yourself; a path in
assets is not sufficient.

Individual per-platform archives are also attached to this release
if you only need one target.
