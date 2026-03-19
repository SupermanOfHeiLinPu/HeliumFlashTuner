cmake_minimum_required(VERSION 3.14)
project(helium_flash_tuner LANGUAGES CXX)

set(BINARY_NAME "helium_flash_tuner")

cmake_policy(SET CMP0063 NEW)

# Flutter library and tool configuration.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application executable.
add_subdirectory("runner")

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake OPTIONAL)

# === Install configuration ===================================================

# By default, <build_dir>/install holds the bundle.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install"
        CACHE PATH "" FORCE)
endif()

set(BUILD_BUNDLE_DIR "${CMAKE_INSTALL_PREFIX}")

# Make the "install" target build a relocatable bundle.
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${BUILD_BUNDLE_DIR}")

# Install Flutter assets/DLLs.
install(
    FILES "${FLUTTER_MANAGED_DIR}/ephemeral/flutter_windows.dll"
    DESTINATION "${BUILD_BUNDLE_DIR}"
)
install(
    DIRECTORY "${FLUTTER_MANAGED_DIR}/ephemeral/cpp_client_wrapper/include"
    DESTINATION "${BUILD_BUNDLE_DIR}"
)

# Install the native JUCE tuner DLL next to the executable so that
# dart:ffi can find it via DynamicLibrary.open('helium_flash_tuner.dll').
install(
    FILES "${CMAKE_SOURCE_DIR}/../native/build/windows/Release/helium_flash_tuner.dll"
    DESTINATION "${BUILD_BUNDLE_DIR}"
    OPTIONAL
)
