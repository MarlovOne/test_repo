include(cmake/SystemLink.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)

macro(test_repo_supports_sanitizers)
  if(((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32) OR(CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*" AND APPLE))
    set(SUPPORTS_UBSAN OFF)
  else()
    set(SUPPORTS_UBSAN ON)
  endif()

  if(((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32) OR(CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*" AND APPLE))
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(test_repo_setup_options)
  option(test_repo_ENABLE_HARDENING "Enable hardening" OFF)
  option(test_repo_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    test_repo_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    test_repo_ENABLE_HARDENING
    OFF)

  test_repo_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR test_repo_PACKAGING_MAINTAINER_MODE)
    option(test_repo_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(test_repo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(test_repo_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(test_repo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(test_repo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test_repo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(test_repo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test_repo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test_repo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test_repo_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(test_repo_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(test_repo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test_repo_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(test_repo_ENABLE_IPO "Enable IPO/LTO" ON)
    option(test_repo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(test_repo_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(test_repo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(test_repo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test_repo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(test_repo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test_repo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test_repo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test_repo_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(test_repo_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(test_repo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test_repo_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      test_repo_ENABLE_IPO
      test_repo_WARNINGS_AS_ERRORS
      test_repo_ENABLE_USER_LINKER
      test_repo_ENABLE_SANITIZER_ADDRESS
      test_repo_ENABLE_SANITIZER_LEAK
      test_repo_ENABLE_SANITIZER_UNDEFINED
      test_repo_ENABLE_SANITIZER_THREAD
      test_repo_ENABLE_SANITIZER_MEMORY
      test_repo_ENABLE_UNITY_BUILD
      test_repo_ENABLE_CLANG_TIDY
      test_repo_ENABLE_CPPCHECK
      test_repo_ENABLE_COVERAGE
      test_repo_ENABLE_PCH
      test_repo_ENABLE_CACHE)
  endif()
endmacro()

macro(test_repo_global_options)
  if(test_repo_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    test_repo_enable_ipo()
  endif()

  test_repo_supports_sanitizers()

  if(test_repo_ENABLE_HARDENING AND test_repo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)

    if(NOT SUPPORTS_UBSAN
      OR test_repo_ENABLE_SANITIZER_UNDEFINED
      OR test_repo_ENABLE_SANITIZER_ADDRESS
      OR test_repo_ENABLE_SANITIZER_THREAD
      OR test_repo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()

    message("${test_repo_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${test_repo_ENABLE_SANITIZER_UNDEFINED}")
    test_repo_enable_hardening(test_repo_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(test_repo_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(test_repo_warnings INTERFACE)
  add_library(test_repo_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  test_repo_set_project_warnings(
    test_repo_warnings
    ${test_repo_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(test_repo_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    test_repo_configure_linker(test_repo_options)
  endif()

  include(cmake/Sanitizers.cmake)
  test_repo_enable_sanitizers(
    test_repo_options
    ${test_repo_ENABLE_SANITIZER_ADDRESS}
    ${test_repo_ENABLE_SANITIZER_LEAK}
    ${test_repo_ENABLE_SANITIZER_UNDEFINED}
    ${test_repo_ENABLE_SANITIZER_THREAD}
    ${test_repo_ENABLE_SANITIZER_MEMORY})

  set_target_properties(test_repo_options PROPERTIES UNITY_BUILD ${test_repo_ENABLE_UNITY_BUILD})

  if(test_repo_ENABLE_PCH)
    target_precompile_headers(
      test_repo_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(test_repo_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    test_repo_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)

  if(test_repo_ENABLE_CLANG_TIDY)
    test_repo_enable_clang_tidy(test_repo_options ${test_repo_WARNINGS_AS_ERRORS})
  endif()

  if(test_repo_ENABLE_CPPCHECK)
    test_repo_enable_cppcheck(${test_repo_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(test_repo_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    test_repo_enable_coverage(test_repo_options)
  endif()

  if(test_repo_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)

    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(test_repo_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(test_repo_ENABLE_HARDENING AND NOT test_repo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)

    if(NOT SUPPORTS_UBSAN
      OR test_repo_ENABLE_SANITIZER_UNDEFINED
      OR test_repo_ENABLE_SANITIZER_ADDRESS
      OR test_repo_ENABLE_SANITIZER_THREAD
      OR test_repo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()

    test_repo_enable_hardening(test_repo_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()
