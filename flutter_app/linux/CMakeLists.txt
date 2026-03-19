cmake_minimum_required(VERSION 3.13)
project(helium_flash_tuner LANGUAGES CXX)

set(BINARY_NAME "helium_flash_tuner")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Flutter library and tool configuration.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  ${FLUTTER_TOOL_ENVIRONMENT}
)

apply_standard_settings(${BINARY_NAME})
target_compile_features(${BINARY_NAME} PRIVATE cxx_std_14)
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Copy the native tuner library into the bundle
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")
install(FILES
  "${CMAKE_SOURCE_DIR}/../native/build/linux/libhelium_flash_tuner.so"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/lib"
  OPTIONAL
)
