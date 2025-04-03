#ifndef NETXTEN_TYPES_CAMERA_TYPE_HPP
#define NETXTEN_TYPES_CAMERA_TYPE_HPP

#include <string_view>
#include <array>
#include <spdlog/spdlog.h>
#include <stdexcept>

namespace netxten::types {

/**
 * @brief Enum for different types of cameras.
 */
enum CameraType {
  UNCOOLED = 1,///< Represents an uncooled camera.
  COOLED   = 2,///< Represents a cooled camera.
  DEFAULT  = -1///< Represents the default camera type.
};

/**
 * @brief Checks whether the given camera type is cooled.
 *
 * @param type The CameraType to check.
 * @return true if the camera type is COOLED.
 * @return false otherwise.
 */
constexpr bool isCooled(CameraType type) { return type == CameraType::COOLED; }

/**
 * @brief Determines the camera cooling type based on the model name.
 *
 * This function checks if the provided camera model string contains any known
 * uncooled model identifiers. If a match is found, it returns CameraType::UNCOOLED;
 * otherwise, it returns CameraType::COOLED.
 *
 * @param camera_model The camera model string to check.
 * @return constexpr CameraType The determined camera type.
 */
constexpr CameraType getCoolingTypeFromModel(std::string_view camera_model)
{
  // Define an array of known uncooled camera model identifiers.
  constexpr std::array<std::string_view, 1> uncooled_models = { "GF77" };

  for (const auto& model : uncooled_models) {
    if (camera_model.find(model) != std::string_view::npos) {
      return CameraType::UNCOOLED;
    }
  }
  // Default to COOLED if no uncooled model identifiers are found.
  return CameraType::COOLED;
}

/**
 * @brief Converts a CameraType enum value to its corresponding lower-case string
 * representation.
 *
 * @param camera_type The CameraType to convert.
 * @return constexpr std::string_view Lower-case string representation ("cooled" or
 * "uncooled").
 */
constexpr std::string_view cameraTypeToString(CameraType camera_type)
{
  switch (camera_type) {
  case CameraType::COOLED:
    return "cooled";
  case CameraType::UNCOOLED:
    return "uncooled";
  case CameraType::DEFAULT:
    return "default";
  default:
    spdlog::error("Invalid camera type: {}", static_cast<int>(camera_type));
    throw std::invalid_argument("Invalid camera type");
  }
}

}// namespace netxten::types

#endif /* NETXTEN_TYPES_CAMERA_TYPE_HPP */