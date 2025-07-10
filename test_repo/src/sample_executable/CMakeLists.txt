add_executable(sample_executable main.cpp)

target_link_libraries(sample_executable PRIVATE test_repo::test_repo_options test_repo::test_repo_warnings
                                                $<BUILD_INTERFACE:Eigen3::Eigen>)

target_link_system_libraries(sample_executable PUBLIC test_repo::sample_library)

# Copy dlls to the target directory to be able to run it
if(WIN32 AND BUILD_SHARED_LIBS)
  add_custom_command(
    TARGET sample_executable
    PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:sample_executable> $<TARGET_FILE_DIR:sample_executable>
    COMMAND_EXPAND_LISTS)

  add_custom_command(
    TARGET sample_executable
    PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:sample_library> $<TARGET_FILE_DIR:sample_executable>
    COMMAND_EXPAND_LISTS)

  # Copy FLIR Science SDK runtime dependencies if available
  if(${FLIR_SCIENCE_SDK_FOUND})
    add_custom_command(
      TARGET netxten_benchmarks
      PRE_BUILD
      COMMAND
        ${CMAKE_COMMAND} -E copy_if_different "${FLIR_SCIENCE_SDK_BINARY_DIRS}/CharLS.dll"
        "${FLIR_SCIENCE_SDK_BINARY_DIRS}/zlib1.dll" "${FLIR_SCIENCE_SDK_BINARY_DIRS}/minizip.dll"
        $<TARGET_FILE_DIR:netxten_benchmarks>
      COMMAND_EXPAND_LISTS)
  endif()
endif()
