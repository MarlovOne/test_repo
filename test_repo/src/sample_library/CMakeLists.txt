add_library(sample_library sample_library.cpp)

add_library(test_repo::sample_library ALIAS sample_library)

target_link_libraries(sample_library PRIVATE test_repo::test_repo_options test_repo::test_repo_warnings
                                             $<BUILD_INTERFACE:${OpenCV_LIBS}>)

target_include_directories(
  sample_library ${WARNING_GUARD}
  PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>
         $<INSTALL_INTERFACE:include>
  PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include" $<BUILD_INTERFACE:${OpenCV_INCLUDE_DIRS}>)

set_target_properties(PROPERTIES VERSION ${PROJECT_VERSION})
