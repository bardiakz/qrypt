#!/usr/bin/env bash
# ==============================================================================
# Build script to compile 16 KB page-aligned native Android libraries
# for arm64-v8a and x86_64:
#   - libesbrotli-android64.so
#   - libeslz4-android64.so
#   - libeszstd-android64.so
#   - liboqs.so
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NDK_DIR="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-/home/chen/Android/Sdk/ndk/29.0.13599879}}"

if [ ! -d "$NDK_DIR" ]; then
  echo "Error: Android NDK not found at $NDK_DIR. Please set ANDROID_NDK_HOME." >&2
  exit 1
fi

STRIP_BIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
LINK_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

# 1. Resolve es_compression path from pub cache
ES_COMP_DIR="$(find "$HOME/.pub-cache/hosted/pub.dev" -maxdepth 1 -type d -name "es_compression-*" | sort -V | tail -n 1)/tool/blob_builder"
if [ ! -d "$ES_COMP_DIR" ]; then
  echo "Error: es_compression tool/blob_builder not found in pub cache." >&2
  exit 1
fi

# 2. Resolve liboqs source
LIBOQS_SRC="/home/chen/StudioProjects/liboqs_compile/liboqs"
if [ ! -d "$LIBOQS_SRC" ]; then
  echo "Warning: liboqs source not found at $LIBOQS_SRC." >&2
fi

ABIS=("arm64-v8a" "x86_64")

for ABI in "${ABIS[@]}"; do
  echo "=========================================="
  echo "Building 16 KB native libraries for $ABI..."
  echo "=========================================="

  OUT_DIR="$ROOT_DIR/android/app/src/main/jniLibs/$ABI"
  mkdir -p "$OUT_DIR"

  # Build es_compression blobs
  BUILD_ES="/tmp/build_es_$ABI"
  rm -rf "$BUILD_ES" && mkdir -p "$BUILD_ES"
  cmake -S "$ES_COMP_DIR" -B "$BUILD_ES" -GNinja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SHARED_LINKER_FLAGS="$LINK_FLAGS"
  ninja -C "$BUILD_ES"

  cp "$BUILD_ES/bin/esbrotli-android64.so" "$OUT_DIR/libesbrotli-android64.so"
  cp "$BUILD_ES/bin/eslz4-android64.so" "$OUT_DIR/libeslz4-android64.so"
  cp "$BUILD_ES/bin/eszstd-android64.so" "$OUT_DIR/libeszstd-android64.so"
  rm -rf "$BUILD_ES"

  # Build liboqs if available
  if [ -d "$LIBOQS_SRC" ]; then
    BUILD_OQS="/tmp/build_oqs_$ABI"
    rm -rf "$BUILD_OQS" && mkdir -p "$BUILD_OQS"
    cmake -S "$LIBOQS_SRC" -B "$BUILD_OQS" -GNinja \
      -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
      -DANDROID_ABI="$ABI" \
      -DANDROID_PLATFORM=android-24 \
      -DOQS_USE_OPENSSL=OFF \
      -DBUILD_SHARED_LIBS=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_SHARED_LINKER_FLAGS="$LINK_FLAGS"
    ninja -C "$BUILD_OQS"

    if [ -x "$STRIP_BIN" ]; then
      "$STRIP_BIN" --strip-unneeded "$BUILD_OQS/lib/liboqs.so"
    fi

    cp "$BUILD_OQS/lib/liboqs.so" "$OUT_DIR/liboqs.so"
    mkdir -p "$ROOT_DIR/liboqs-0.16.0/android/$ABI"
    cp "$BUILD_OQS/lib/liboqs.so" "$ROOT_DIR/liboqs-0.16.0/android/$ABI/liboqs.so"
    rm -rf "$BUILD_OQS"
  fi
done

echo ""
echo "Running verification..."
python3 "$ROOT_DIR/tool/check_android_elf_alignment.py"
