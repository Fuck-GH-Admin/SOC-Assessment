cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Optional generated native table for the isolated REA protection build.
# A normal developer checkout compiles without it (and without OpenSSL).
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/protected_soc_table_generated.cc")
  find_package(OpenSSL REQUIRED)
  target_sources(${BINARY_NAME} PRIVATE "protected_soc_table_generated.cc")
  target_link_libraries(${BINARY_NAME} PRIVATE OpenSSL::Crypto)
  # Required for Dart FFI DynamicLibrary.process() to find soc_data_access.
  set_target_properties(${BINARY_NAME} PROPERTIES ENABLE_EXPORTS ON)
endif()
# REA experiment: strengthen the Linux launcher in release builds.
# This targets only the native runner; Dart AOT uses Flutter's toolchain.
# Avoid debugger detection in business logic to preserve functionality.
target_compile_options(${BINARY_NAME} PRIVATE
  "$<$<CONFIG:Release>:-fstack-protector-strong>"
  "$<$<CONFIG:Release>:-D_FORTIFY_SOURCE=2>"
)
target_link_options(${BINARY_NAME} PRIVATE
  "$<$<CONFIG:Release>:-Wl,-z,relro>"
  "$<$<CONFIG:Release>:-Wl,-z,now>"
  "$<$<CONFIG:Release>:-Wl,-z,noexecstack>"
)
