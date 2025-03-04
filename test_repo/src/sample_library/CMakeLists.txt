add_library(sample_library sample_library.cpp)

add_library(test_repo::sample_library ALIAS sample_library)

target_link_libraries(
  sample_library
  PRIVATE test_repo::test_repo_options
          test_repo::test_repo_warnings
          $<BUILD_INTERFACE:${OpenCV_LIBS}>
          $<BUILD_INTERFACE:spdlog::spdlog>
          $<BUILD_INTERFACE:Eigen3::Eigen>
          $<BUILD_INTERFACE:liquid::liquid>
          $<BUILD_INTERFACE:nlohmann_json::nlohmann_json>)

if(${CMAKE_SYSTEM_NAME} STREQUAL "iOS" OR IOS)
  message(STATUS "Linking frameworks for iOS")
  target_link_libraries(
    sample_library
    PRIVATE "-framework AVFoundation"
            "-framework UIKit"
            "-framework Foundation" # Added to resolve missing symbols
            "-framework CoreFoundation"
            "-framework CoreMedia")
endif()

target_include_directories(
  sample_library ${WARNING_GUARD}
  PUBLIC $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
         $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>
         $<INSTALL_INTERFACE:include>
         $<BUILD_INTERFACE:${OpenCV_INCLUDE_DIRS}>
  PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include" $<BUILD_INTERFACE:${CPPYSTRUCT_SOURCE_DIR}/include>)

set_target_properties(sample_library PROPERTIES VERSION ${PROJECT_VERSION} POSITION_INDEPENDENT_CODE ON)

if(WIN32 AND BUILD_SHARED_LIBS)
  # TODO(lmark): Replace this with autmatically generated export macros
  # TODO(lmark): hide visibility of all symbols except the ones we want to export
  target_compile_definitions(sample_library PRIVATE SAMPLE_LIBRARY_EXPORTS)
endif()
