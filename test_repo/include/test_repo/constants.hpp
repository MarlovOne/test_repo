#ifndef NETXTEN_CONFIG_CONSTANTS_HPP
#define NETXTEN_CONFIG_CONSTANTS_HPP

inline constexpr auto ZERO_THRESHOLD          = 1e-6;
inline constexpr auto MAX_PIXEL_VALUE         = 255;
inline constexpr auto MIN_PIXEL_VALUE         = 0;
inline constexpr auto RUNNING_STDDEV_MAX_DIFF = 50;
inline constexpr auto CSQ_BIT_COUNT           = 16;
inline constexpr auto SCALE_FACTOR            = 257.0;
inline constexpr auto FRAME_STATS_BUFFER_SIZE = 3000;

#endif /* NETXTEN_CONFIG_CONSTANTS */