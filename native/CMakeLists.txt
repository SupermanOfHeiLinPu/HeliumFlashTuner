cmake_minimum_required(VERSION 3.22)
project(helium_flash_tuner_native VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(APPLE)
    enable_language(OBJCXX)
    set(CMAKE_OBJCXX_STANDARD 17)
    set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
    set(CMAKE_OBJCXX_EXTENSIONS OFF)
endif()

# ---------------------------------------------------------------------------
# JUCE
# ---------------------------------------------------------------------------
# JUCE must be available as a subdirectory.  Either:
#   a) git clone JUCE into <repo>/native/JUCE, or
#   b) set JUCE_PATH to the JUCE root via -DJUCE_PATH=/path/to/JUCE
# ---------------------------------------------------------------------------

if(NOT DEFINED JUCE_PATH)
    set(JUCE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/JUCE")
endif()

if(NOT EXISTS "${JUCE_PATH}/CMakeLists.txt")
    message(FATAL_ERROR
        "JUCE not found at '${JUCE_PATH}'.\n"
        "Please clone JUCE 8.x into native/JUCE or pass -DJUCE_PATH=/path/to/JUCE")
endif()

add_subdirectory("${JUCE_PATH}" JUCE EXCLUDE_FROM_ALL)

# ---------------------------------------------------------------------------
# Shared library (loaded by Flutter via dart:ffi)
# ---------------------------------------------------------------------------

add_library(helium_flash_tuner SHARED
    Source/TunerBridge.cpp
    Source/TunerProcessor.cpp
    Source/PitchDetector.cpp
)

target_include_directories(helium_flash_tuner
    PRIVATE
        Source
)

# Expose the JUCE headers and link the required modules.
target_link_libraries(helium_flash_tuner
    PRIVATE
    juce::juce_audio_basics
    juce::juce_audio_devices
    juce::juce_dsp
    juce::juce_core
)

# Make all symbols hidden by default; only functions marked TUNER_EXPORT
# are visible in the shared library.
set_target_properties(helium_flash_tuner PROPERTIES
    CXX_VISIBILITY_PRESET     hidden
    VISIBILITY_INLINES_HIDDEN YES
)

# Compiler flags
target_compile_options(helium_flash_tuner PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:
        -Wall -Wextra -Wpedantic -O2>
    $<$<CXX_COMPILER_ID:MSVC>:
        /W3 /O2>
)

# ---------------------------------------------------------------------------
# Android-specific: strip debug symbols from release build
# ---------------------------------------------------------------------------
if(ANDROID)
    set_target_properties(helium_flash_tuner PROPERTIES
        ANDROID_STRIP_DEBUG_SYMBOLS TRUE
    )
endif()

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------
install(TARGETS helium_flash_tuner
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
