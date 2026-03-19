#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Build the native JUCE tuner library for Linux (x86_64)
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(dirname "${SCRIPT_DIR}")"
BUILD_DIR="${NATIVE_DIR}/build/linux"

echo "==> Creating build directory: ${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

echo "==> Configuring with CMake …"
cmake "${NATIVE_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}/install" \
    ${JUCE_PATH:+-DJUCE_PATH="${JUCE_PATH}"}

echo "==> Building …"
cmake --build . --config Release --parallel "$(nproc)"

echo "==> Installing …"
cmake --install . --config Release

echo ""
echo "✓ Library built: ${BUILD_DIR}/libhelium_flash_tuner.so"
echo ""
echo "Copy it to the Flutter Linux bundle:"
echo "  cp ${BUILD_DIR}/libhelium_flash_tuner.so  <flutter_app>/linux/bundle/lib/"
