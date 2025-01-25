add_executable(intro main.cpp)

target_link_libraries(
  intro
  PRIVATE test_repo::test_repo_options
  test_repo::test_repo_warnings)

target_link_system_libraries(
  intro
  PRIVATE)

target_include_directories(intro PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include")
