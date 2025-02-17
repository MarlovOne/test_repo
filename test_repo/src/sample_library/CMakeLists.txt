add_library(sample_library sample_library.cpp)

add_library(test_repo::sample_library ALIAS sample_library)

target_link_libraries(
  sample_library
  PRIVATE test_repo::test_repo_options
          test_repo::test_repo_warnings
          $<BUILD_INTERFACE:${OpenCV_LIBS}>
          $<BUILD_INTERFACE:spdlog::spdlog>)

target_include_directories(
  sample_library ${WARNING_GUARD}
  PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>
         $<INSTALL_INTERFACE:include>
  PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include" $<BUILD_INTERFACE:${OpenCV_INCLUDE_DIRS}>
          $<BUILD_INTERFACE:${CPPYSTRUCT_SOURCE_DIR}/include>)

set_target_properties(sample_library PROPERTIES VERSION ${PROJECT_VERSION} POSITION_INDEPENDENT_CODE ON)

if(WIN32 AND BUILD_SHARED_LIBS)
  # TODO(lmark): Replace this with autmatically generated export macros
  # TODO(lmark): hide visibility of all symbols except the ones we want to export
  target_compile_definitions(sample_library PRIVATE SAMPLE_LIBRARY_EXPORTS)
endif()
