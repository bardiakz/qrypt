import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:oqs/oqs.dart';
import 'package:path/path.dart' as path;

class OqsLoader {
  static String getExecutableDir() {
    final execPath = Platform.resolvedExecutable;
    return File(execPath).parent.path;
  }

  static void initialize() {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        LibOQS.init();
      } catch (e) {
        debugPrint('Warning: LibOQS.init() failed on mobile: $e');
      }
      return;
    }

    final String execDir = getExecutableDir();
    final String currentDir = Directory.current.path;

    final candidateArchiveRoots = [
      path.join(currentDir, 'liboqs-0.16.0'),
      path.join(execDir, 'liboqs-0.16.0'),
      path.join(execDir, 'data', 'flutter_assets', 'liboqs-0.16.0'),
    ];

    String? foundRoot;
    for (final root in candidateArchiveRoots) {
      if (Directory(root).existsSync()) {
        foundRoot = root;
        break;
      }
    }

    String? linuxX64;
    String? linuxArm64;
    String? windows;
    String? macOS;

    if (Platform.isLinux) {
      final candidateFiles = [
        path.join(execDir, 'lib', 'liboqs.so'),
        path.join(execDir, 'liboqs.so'),
        if (foundRoot != null) path.join(foundRoot, 'linux', 'x86_64', 'liboqs.so'),
      ];
      for (final f in candidateFiles) {
        if (File(f).existsSync()) {
          linuxX64 = f;
          break;
        }
      }

      final candidateArmFiles = [
        path.join(execDir, 'lib', 'liboqs.so'),
        path.join(execDir, 'liboqs.so'),
        if (foundRoot != null) path.join(foundRoot, 'linux', 'aarch64', 'liboqs.so'),
      ];
      for (final f in candidateArmFiles) {
        if (File(f).existsSync()) {
          linuxArm64 = f;
          break;
        }
      }
    } else if (Platform.isWindows) {
      final candidateFiles = [
        path.join(execDir, 'oqs.dll'),
        path.join(execDir, 'lib', 'oqs.dll'),
        if (foundRoot != null) path.join(foundRoot, 'windows', 'x86_64', 'oqs.dll'),
      ];
      for (final f in candidateFiles) {
        if (File(f).existsSync()) {
          windows = f;
          break;
        }
      }
    } else if (Platform.isMacOS) {
      final macArch = Abi.current() == Abi.macosX64 ? 'x86_64' : 'arm64';
      final candidateFiles = [
        path.join(execDir, '..', 'Frameworks', 'liboqs.dylib'),
        path.join(execDir, 'liboqs.dylib'),
        if (foundRoot != null) path.join(foundRoot, 'macos', macArch, 'liboqs.dylib'),
      ];
      for (final f in candidateFiles) {
        if (File(f).existsSync()) {
          macOS = f;
          break;
        }
      }
    }

    if (linuxX64 != null || linuxArm64 != null || windows != null || macOS != null) {
      LibOQSLoader.customPaths = LibraryPaths(
        linuxX64: linuxX64,
        linuxArm64: linuxArm64,
        windows: windows,
        macOS: macOS,
      );
    } else if (foundRoot != null) {
      LibOQSLoader.customPaths = LibraryPaths.fromReleaseArchive(foundRoot);
    } else {
      LibOQSLoader.customPaths = LibraryPaths.fromReleaseArchive('liboqs-0.16.0');
    }

    try {
      LibOQS.init();
    } catch (e) {
      debugPrint('Warning: LibOQS.init() failed: $e');
    }
  }
}
