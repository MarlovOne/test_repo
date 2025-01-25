add_executable(sample_executable main.cpp)

target_link_libraries(sample_executable PRIVATE test_repo::test_repo_options test_repo::test_repo_warnings)

target_link_system_libraries(sample_executable 
    PRIVATE 
    test_repo::sample_library)

# Copy dlls to the target directory to be able to run it
if(WIN32 AND BUILD_SHARED_LIBS)
  add_custom_command(
    TARGET sample_executable
    PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_RUNTIME_DLLS:sample_executable> $<TARGET_FILE_DIR:sample_executable>
    COMMAND_EXPAND_LISTS)
endif()