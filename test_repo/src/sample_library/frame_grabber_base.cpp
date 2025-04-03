#include <spdlog/spdlog.h>
#include <test_repo/frame_grabber_base.hpp>

using namespace netxten::utils;

FrameGrabberBase::FrameGrabberBase(std::string path) : m_file_path(std::move(path)), m_file(nullptr) {}

FrameGrabberBase::~FrameGrabberBase()
{
  spdlog::info("FrameGrabberBase destructor");
  close();
}

FrameGrabberBase::FrameGrabberBase(FrameGrabberBase &&other) noexcept
  : m_file_path(std::move(other.m_file_path)), m_file(std::move(other.m_file))
{
  other.close();
}

FrameGrabberBase &FrameGrabberBase::operator=(FrameGrabberBase &&other) noexcept
{
  if (this != &other) {
    close();
    m_file_path = std::move(other.m_file_path);
    m_file = std::move(other.m_file);
    other.close();
  }
  return *this;
}

void FrameGrabberBase::initialize()
{
  if (m_file_path.empty()) {
    spdlog::warn("[FrameGrabberBase::initialize] File path is empty. Skipping initialization");
    setup();
    m_is_initialized = true;
    return;
  }

  m_file = std::make_unique<std::ifstream>(m_file_path, std::ios::binary);
  if (m_file->is_open()) {
    setup();
    m_is_initialized = true;
  } else {
    std::cerr << "Error opening file: " << m_file_path << std::endl;
    throw std::runtime_error("[FrameGrabberBase] Error opening file: " + m_file_path);
  }
}

void FrameGrabberBase::close()
{
  if (m_file && m_file->is_open()) { m_file->close(); }
  m_file.reset();
}

void FrameGrabberBase::checkInitialization() const
{
  if (m_is_initialized) { return; }
  spdlog::warn("Frame grabber is not initialized.");
  throw std::runtime_error("Frame grabber is not initialized.");
}

double FrameGrabberBase::getFrameRate() const
{
  if (m_frame_rate_opt.has_value()) { return m_frame_rate_opt.value(); }
  spdlog::warn("FrameGrabberBase::getFrameRate() not implemented.");
  return -1;
}

std::string FrameGrabberBase::getCameraModel() const
{
  if (m_camera_model_opt.has_value()) { return m_camera_model_opt.value(); }
  spdlog::warn("FrameGrabberBase::getCameraModel() not implemented.");
  return "unkown";
}

netxten::types::CameraType FrameGrabberBase::getCameraType() const
{
  if (m_camera_type_opt.has_value()) { return m_camera_type_opt.value(); }
  auto model = getCameraModel();
  spdlog::info("Getting camera type from model: {}", model);
  return netxten::types::getCoolingTypeFromModel(model);
}

void FrameGrabberBase::setFrameRate(double frame_rate)
{
  spdlog::info("FrameGrabberBase::setFrameRate() - {}.", frame_rate);
  m_frame_rate_opt = frame_rate;
}

void FrameGrabberBase::setCameraModel(std::string camera_model)
{
  spdlog::info("FrameGrabberBase::setCameraModel() - {}.", camera_model);
  m_camera_model_opt = std::move(camera_model);
}

void FrameGrabberBase::setCameraType(netxten::types::CameraType camera_type)
{
  spdlog::info("FrameGrabberBase::setCameraType() - {}.", static_cast<int>(camera_type));
  m_camera_type_opt = camera_type;
}