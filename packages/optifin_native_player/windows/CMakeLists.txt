cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "optifin_native_player")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "optifin_native_player_plugin")

# ------------------------------------------------------------------ libmpv
# libmpv récente (compilation shinchiro, rendu gpu-next / libplacebo : HDR et Dolby Vision
# sur PC). Téléchargée une fois, vérifiée par empreinte SHA-256, jamais versionnée.
set(LIBMPV_ARCHIVE "mpv-dev-x86_64-20260928-git-e470f8986e.7z")
set(LIBMPV_URL "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/20260928/${LIBMPV_ARCHIVE}")
set(LIBMPV_SHA256 "81795d759e01016f1550fd71651a1a5d59ab5c28ef31c0b6793224e9cff39459")
set(LIBMPV_DIR "${CMAKE_BINARY_DIR}/libmpv-20260928")

if(NOT EXISTS "${LIBMPV_DIR}/libmpv-2.dll")
  message(STATUS "OptiFin : téléchargement de libmpv (${LIBMPV_ARCHIVE})")
  file(DOWNLOAD "${LIBMPV_URL}" "${CMAKE_BINARY_DIR}/${LIBMPV_ARCHIVE}"
    EXPECTED_HASH SHA256=${LIBMPV_SHA256}
    TLS_VERIFY ON
    SHOW_PROGRESS)
  file(ARCHIVE_EXTRACT INPUT "${CMAKE_BINARY_DIR}/${LIBMPV_ARCHIVE}" DESTINATION "${LIBMPV_DIR}")
  file(REMOVE "${CMAKE_BINARY_DIR}/${LIBMPV_ARCHIVE}")
endif()

# ------------------------------------------------------------------ Plugin
add_library(${PLUGIN_NAME} SHARED
  "optifin_native_player_plugin.cpp"
  "mpv_player.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_20)
target_compile_options(${PLUGIN_NAME} PRIVATE /await:strict /utf-8)
target_include_directories(${PLUGIN_NAME}
  INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include"
  PRIVATE "${LIBMPV_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  windowsapp dwmapi shell32 ole32 powrprof)

# libmpv-2.dll à côté de l'exécutable (chargée à la première lecture).
set(optifin_native_player_bundled_libraries
  "${LIBMPV_DIR}/libmpv-2.dll"
  PARENT_SCOPE
)
