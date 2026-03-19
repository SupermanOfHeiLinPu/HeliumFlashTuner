#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Cross-compile the native JUCE tuner library for Android
# Prerequisites:
#   - Android NDK r25+ (set ANDROID_NDK_ROOT or pass -DANDROID_NDK=<path>)
#   - CMake 3.22+
#   - JUCE 8.x cloned into native/JUCE (or set JUCE_PATH)
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$(dirname "${SCRIPT_DIR}")"

NDK="${ANDROID_NDK_ROOT:-${ANDROID_NDK:-}}"
if [[ -z "${NDK}" ]]; then
    echo "ERROR: set ANDROID_NDK_ROOT to your NDK path." >&2
    exit 1
fi

TOOLCHAIN="${NDK}/build/cmake/android.toolchain.cmake"
API_LEVEL="${ANDROID_API_LEVEL:-23}"

ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")

build_abi() {
    local abi="$1"
    local dir="${NATIVE_DIR}/build/android/${abi}"
    echo "==> Building ABI: ${abi} …"
    mkdir -p "${dir}"
    cmake "${NATIVE_DIR}" -B "${dir}" \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}" \
        -DANDROID_ABI="${abi}" \
        -DANDROID_PLATFORM="android-${API_LEVEL}" \
        -DCMAKE_BUILD_TYPE=Release \
        ${JUCE_PATH:+-DJUCE_PATH="${JUCE_PATH}"}
    cmake --build "${dir}" --config Release --parallel "$(nproc)"
}

for abi in "${ABIS[@]}"; do
    build_abi "${abi}"
done

echo ""
echo "✓ Android libraries built."
echo ""
echo "Copy them to the Flutter project:"
for abi in "${ABIS[@]}"; do
    echo "  cp ${NATIVE_DIR}/build/android/${abi}/libhelium_flash_tuner.so \\"
    echo "     <flutter_app>/android/app/src/main/jniLibs/${abi}/"
done
