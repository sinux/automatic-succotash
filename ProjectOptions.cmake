include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(automatic_succotash_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(automatic_succotash_setup_options)
  option(automatic_succotash_ENABLE_HARDENING "Enable hardening" ON)
  option(automatic_succotash_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    automatic_succotash_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    automatic_succotash_ENABLE_HARDENING
    OFF)

  automatic_succotash_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR automatic_succotash_PACKAGING_MAINTAINER_MODE)
    option(automatic_succotash_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(automatic_succotash_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(automatic_succotash_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(automatic_succotash_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(automatic_succotash_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(automatic_succotash_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(automatic_succotash_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(automatic_succotash_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(automatic_succotash_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(automatic_succotash_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(automatic_succotash_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(automatic_succotash_ENABLE_PCH "Enable precompiled headers" OFF)
    option(automatic_succotash_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(automatic_succotash_ENABLE_IPO "Enable IPO/LTO" ON)
    option(automatic_succotash_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(automatic_succotash_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(automatic_succotash_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(automatic_succotash_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(automatic_succotash_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(automatic_succotash_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(automatic_succotash_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(automatic_succotash_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(automatic_succotash_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(automatic_succotash_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(automatic_succotash_ENABLE_PCH "Enable precompiled headers" OFF)
    option(automatic_succotash_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      automatic_succotash_ENABLE_IPO
      automatic_succotash_WARNINGS_AS_ERRORS
      automatic_succotash_ENABLE_USER_LINKER
      automatic_succotash_ENABLE_SANITIZER_ADDRESS
      automatic_succotash_ENABLE_SANITIZER_LEAK
      automatic_succotash_ENABLE_SANITIZER_UNDEFINED
      automatic_succotash_ENABLE_SANITIZER_THREAD
      automatic_succotash_ENABLE_SANITIZER_MEMORY
      automatic_succotash_ENABLE_UNITY_BUILD
      automatic_succotash_ENABLE_CLANG_TIDY
      automatic_succotash_ENABLE_CPPCHECK
      automatic_succotash_ENABLE_COVERAGE
      automatic_succotash_ENABLE_PCH
      automatic_succotash_ENABLE_CACHE)
  endif()

  automatic_succotash_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (automatic_succotash_ENABLE_SANITIZER_ADDRESS OR automatic_succotash_ENABLE_SANITIZER_THREAD OR automatic_succotash_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(automatic_succotash_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(automatic_succotash_global_options)
  if(automatic_succotash_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    automatic_succotash_enable_ipo()
  endif()

  automatic_succotash_supports_sanitizers()

  if(automatic_succotash_ENABLE_HARDENING AND automatic_succotash_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR automatic_succotash_ENABLE_SANITIZER_UNDEFINED
       OR automatic_succotash_ENABLE_SANITIZER_ADDRESS
       OR automatic_succotash_ENABLE_SANITIZER_THREAD
       OR automatic_succotash_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${automatic_succotash_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${automatic_succotash_ENABLE_SANITIZER_UNDEFINED}")
    automatic_succotash_enable_hardening(automatic_succotash_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(automatic_succotash_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(automatic_succotash_warnings INTERFACE)
  add_library(automatic_succotash_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  automatic_succotash_set_project_warnings(
    automatic_succotash_warnings
    ${automatic_succotash_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(automatic_succotash_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(automatic_succotash_options)
  endif()

  include(cmake/Sanitizers.cmake)
  automatic_succotash_enable_sanitizers(
    automatic_succotash_options
    ${automatic_succotash_ENABLE_SANITIZER_ADDRESS}
    ${automatic_succotash_ENABLE_SANITIZER_LEAK}
    ${automatic_succotash_ENABLE_SANITIZER_UNDEFINED}
    ${automatic_succotash_ENABLE_SANITIZER_THREAD}
    ${automatic_succotash_ENABLE_SANITIZER_MEMORY})

  set_target_properties(automatic_succotash_options PROPERTIES UNITY_BUILD ${automatic_succotash_ENABLE_UNITY_BUILD})

  if(automatic_succotash_ENABLE_PCH)
    target_precompile_headers(
      automatic_succotash_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(automatic_succotash_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    automatic_succotash_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(automatic_succotash_ENABLE_CLANG_TIDY)
    automatic_succotash_enable_clang_tidy(automatic_succotash_options ${automatic_succotash_WARNINGS_AS_ERRORS})
  endif()

  if(automatic_succotash_ENABLE_CPPCHECK)
    automatic_succotash_enable_cppcheck(${automatic_succotash_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(automatic_succotash_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    automatic_succotash_enable_coverage(automatic_succotash_options)
  endif()

  if(automatic_succotash_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(automatic_succotash_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(automatic_succotash_ENABLE_HARDENING AND NOT automatic_succotash_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR automatic_succotash_ENABLE_SANITIZER_UNDEFINED
       OR automatic_succotash_ENABLE_SANITIZER_ADDRESS
       OR automatic_succotash_ENABLE_SANITIZER_THREAD
       OR automatic_succotash_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    automatic_succotash_enable_hardening(automatic_succotash_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
