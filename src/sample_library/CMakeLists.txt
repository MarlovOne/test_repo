add_library(sample_library sample_library.cpp)

add_library(test_repo::sample_library ALIAS sample_library)

target_link_libraries(sample_library PRIVATE test_repo_options test_repo_warnings)

target_include_directories(sample_library ${WARNING_GUARD} PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
  $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>)

# Set target properties to hide symbols by default
set_target_properties(
  sample_library
  PROPERTIES VERSION ${PROJECT_VERSION}
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN YES)

# Add the export header generation to mark the symbols as exported
include(GenerateExportHeader)
generate_export_header(sample_library 
  EXPORT_FILE_NAME ${PROJECT_BINARY_DIR}/include/test_repo/sample_library_export.hpp)

# Need to add *_STATIC_DEFINE to bybass the export macros ONLY in static libraries
if(NOT BUILD_SHARED_LIBS)
  target_compile_definitions(sample_library PUBLIC SAMPLE_LIBRARY_STATIC_DEFINE)
endif()
