add_library(sample_library sample_library.cpp)

add_library(test_repo::sample_library ALIAS sample_library)

target_link_libraries(sample_library PRIVATE test_repo::test_repo_options test_repo::test_repo_warnings)

target_include_directories(
  sample_library ${WARNING_GUARD}
  PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>
  PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include")

set_target_properties(
  PROPERTIES VERSION ${PROJECT_VERSION}
             CXX_VISIBILITY_PRESET hidden
             VISIBILITY_INLINES_HIDDEN YES)

include(GenerateExportHeader)
generate_export_header(sample_library EXPORT_FILE_NAME
                       ${PROJECT_BINARY_DIR}/include/test_repo/sample_library_export.hpp)

if(NOT BUILD_SHARED_LIBS)
  target_compile_definitions(sample_library PUBLIC SAMPLE_LIBRARY_STATIC_DEFINE)
endif()
