# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(atlas_tts_library VERSION 0.0.1 LANGUAGES C)

# C99: the core uses mixed declarations and // comments.
set(CMAKE_C_STANDARD 99)

add_library(atlas_tts SHARED
  "atlas_tts.c"
)

set_target_properties(atlas_tts PROPERTIES
  PUBLIC_HEADER atlas_tts.h
  OUTPUT_NAME "atlas_tts"
)

target_compile_definitions(atlas_tts PUBLIC DART_SHARED_LIB)

if (UNIX)
  # sin() on Android/Linux toolchains; Windows auto-links libm/ucrt.
  target_link_libraries(atlas_tts PRIVATE m)
endif()

if (WIN32)
  # Playback device consumer (M3 host slice): winmm waveOut backend.
  target_link_libraries(atlas_tts PRIVATE winmm)
endif()

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(atlas_tts PRIVATE "-Wl,-z,max-page-size=16384")

  # Optional sherpa-onnx Android runtime (neural backend). Auto-detected from
  # the native_deps tree next to this CMakeLists (native_deps/android/<ABI>/),
  # fetched by tool/fetch_voice_pack.ps1; without it the core builds onto the
  # sine fallback like any other client. Importing via absolute paths keeps
  # gradle's flag interface untouched. The .so files are PACKAGED by gradle
  # via the plugin's jniLibs.srcDirs (android/build.gradle), not by a
  # copy-to-output trick.
  set(_atlas_sherpa_android
      "${CMAKE_CURRENT_SOURCE_DIR}/../native_deps/android/jniLibs/${ANDROID_ABI}")
  if (EXISTS "${_atlas_sherpa_android}/libsherpa-onnx-c-api.so")
    target_include_directories(atlas_tts PRIVATE
      "${CMAKE_CURRENT_SOURCE_DIR}/../native_deps/sherpa-onnx")
    target_compile_definitions(atlas_tts PRIVATE ATLAS_TTS_WITH_SHERPA)
    add_library(sherpa-onnx-c-api SHARED IMPORTED)
    set_target_properties(sherpa-onnx-c-api PROPERTIES IMPORTED_LOCATION
      "${_atlas_sherpa_android}/libsherpa-onnx-c-api.so")
    add_library(onnxruntime SHARED IMPORTED)
    set_target_properties(onnxruntime PROPERTIES IMPORTED_LOCATION
      "${_atlas_sherpa_android}/libonnxruntime.so")
    if (EXISTS "${_atlas_sherpa_android}/libonnxruntime_providers_shared.so")
      add_library(onnxruntime_providers_shared SHARED IMPORTED)
      set_target_properties(onnxruntime_providers_shared PROPERTIES
        IMPORTED_LOCATION
        "${_atlas_sherpa_android}/libonnxruntime_providers_shared.so")
      target_link_libraries(atlas_tts PRIVATE onnxruntime_providers_shared)
    endif()
    target_link_libraries(atlas_tts PRIVATE sherpa-onnx-c-api onnxruntime)
  else()
    message(STATUS
      "atlas_tts: no sherpa-onnx Android runtime for ABI ${ANDROID_ABI} "
      "under ${CMAKE_CURRENT_SOURCE_DIR}/../native_deps/android")
  endif()
endif()

# ---------------------------------------------------------------------------
# Optional sherpa-onnx neural backend (M2). Pass
#   -DATLAS_SHERPA_RUNTIME:PATH=<atlas_tts>/native_deps
# (a native_deps/ root holding a sherpa-onnx-*-win-x64-shared-*-lib tree and
# sherpa-onnx/sherpa-onnx/c-api/c-api.h). Without it the core builds onto the
# M1 sine fallback, which is dev/test only — real voice packs then fail loud
# at load_voice/speak rather than silently degrading.
# ---------------------------------------------------------------------------
set(ATLAS_SHERPA_RUNTIME "" CACHE PATH "sherpa-onnx native_deps root")
if (ATLAS_SHERPA_RUNTIME)
  file(GLOB _sherpa_lib_dir
       "${ATLAS_SHERPA_RUNTIME}/sherpa-onnx-*-win-x64-shared-MD-Release-lib/lib")
  if (_sherpa_lib_dir)
    list(GET _sherpa_lib_dir 0 _sherpa_lib)
    target_include_directories(atlas_tts PRIVATE
      "${ATLAS_SHERPA_RUNTIME}/sherpa-onnx")
    target_compile_definitions(atlas_tts PRIVATE ATLAS_TTS_WITH_SHERPA)
    target_link_libraries(atlas_tts PRIVATE
      "${_sherpa_lib}/sherpa-onnx-c-api.lib")
    # Runtime DLLs must sit next to atlas_tts.dll for test/probe runs (the
    # Dart loaders also preload them by absolute path — belt and braces).
    add_custom_command(TARGET atlas_tts POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${_sherpa_lib}/sherpa-onnx-c-api.dll"
        "${_sherpa_lib}/sherpa-onnx-cxx-api.dll"
        "${_sherpa_lib}/onnxruntime.dll"
        "$<TARGET_FILE_DIR:atlas_tts>")
    if (EXISTS "${_sherpa_lib}/onnxruntime_providers_shared.dll")
      add_custom_command(TARGET atlas_tts POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${_sherpa_lib}/onnxruntime_providers_shared.dll"
          "$<TARGET_FILE_DIR:atlas_tts>")
    endif()
  else()
    message(FATAL_ERROR
      "ATLAS_SHERPA_RUNTIME set but no sherpa-onnx win-x64 shared lib tree "
      "found under ${ATLAS_SHERPA_RUNTIME}")
  endif()
endif()
