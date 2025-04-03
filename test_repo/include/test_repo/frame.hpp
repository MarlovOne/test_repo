#ifndef NETXTEN_FRAME_HPP
#define NETXTEN_FRAME_HPP

#include <Eigen/Dense>

namespace netxten::types {

template<typename T> using Frame = Eigen::Matrix<T, Eigen::Dynamic, Eigen::Dynamic>;
using Frame16                    = Frame<uint16_t>;
using Vector16                   = Eigen::Matrix<uint16_t, Eigen::Dynamic, 1>;
using FrameFloat                 = Frame<float>;
using FrameDouble                = Frame<double>;

/**
 * @brief Structure to hold the height and width of a frame.
 *
 */
struct FrameSize
{
  std::size_t height = 0;//*< The height of the frame. */
  std::size_t width  = 0;//*< The width of the frame. */
};

struct FrameInfo
{
  FrameSize size;//*< The size of the frame. */
  size_t    num_pixels;//*< The number of pixels in the frame. */
  double    frame_rate;//*< The frame rate of the frame. */
};

struct TSFrameInfo
{
  int64_t pts;
  int64_t dts;
  bool    is_keyframe;
  int64_t position;
};

}// namespace netxten::types

#endif /* NETXTEN_FRAME */
