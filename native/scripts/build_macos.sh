#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Build the native JUCE tuner library for macOS (arm64 + x86_64 universal)
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(dirname "${SCRIPT_DIR}")"

BUILD_ARM="${NATIVE_DIR}/build/macos_arm64"
BUILD_X86="${NATIVE_DIR}/build/macos_x86_64"
BUILD_UNI="${NATIVE_DIR}/build/macos_universal"

CMAKE_FLAGS=(
    -DCMAKE_BUILD_TYPE=Release
    ${JUCE_PATH:+-DJUCE_PATH="${JUCE_PATH}"}
)

build_arch() {
    local arch="$1"
    local dir="$2"
    echo "==> Building ${arch} …"
    mkdir -p "${dir}"
    cmake "${NATIVE_DIR}" -B "${dir}" \
        "${CMAKE_FLAGS[@]}" \
        -DCMAKE_OSX_ARCHITECTURES="${arch}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0"
    cmake --build "${dir}" --config Release --parallel "$(sysctl -n hw.logicalcpu)"
}

build_arch arm64  "${BUILD_ARM}"
build_arch x86_64 "${BUILD_X86}"

echo "==> Creating universal binary …"
mkdir -p "${BUILD_UNI}"
lipo -create \
    "${BUILD_ARM}/libhelium_flash_tuner.dylib" \
    "${BUILD_X86}/libhelium_flash_tuner.dylib" \
    -output "${BUILD_UNI}/libhelium_flash_tuner.dylib"

echo ""
echo "✓ Universal library built: ${BUILD_UNI}/libhelium_flash_tuner.dylib"
echo ""
echo "Copy it to the Flutter macOS bundle:"
echo "  cp ${BUILD_UNI}/libhelium_flash_tuner.dylib  <flutter_app>/macos/Runner/"
