cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or flutter run will break.
add_executable(${BINARY_NAME} WIN32
    "flutter_window.cpp"
    "main.cpp"
    "utils.cpp"
    "win32_window.cpp"
    "Runner.rc"
    "${FLUTTER_TOOL_ENVIRONMENT}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/generated_plugin_registrant.cc"
)

apply_standard_settings(${BINARY_NAME})

# Disable Windows macros that conflict with C++ standard library.
target_compile_definitions(${BINARY_NAME} PRIVATE
    "NOMINMAX"
    "UNICODE"
    "_UNICODE"
)

target_compile_features(${BINARY_NAME} PRIVATE cxx_std_17)

target_link_libraries(${BINARY_NAME} PRIVATE
    flutter
    flutter_wrapper_app
)
target_include_directories(${BINARY_NAME} PRIVATE
    "${CMAKE_SOURCE_DIR}"
)

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Only the runner's Debug config maps to the Flutter Debug config; the rest
# (Profile and Release) all map to the Flutter Release config.
set_target_properties(${BINARY_NAME} PROPERTIES
    DEBUG_POSTFIX ""
)
