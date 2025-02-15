#ifndef EXPORT_MACROS_HPP
#define EXPORT_MACROS_HPP

// TODO(lmark): add automatically generated export headers
#ifdef _WIN32
#ifdef SAMPLE_LIBRARY_EXPORTS
#define SAMPLE_LIBRARY_API __declspec(dllexport)
#else
#define SAMPLE_LIBRARY_API __declspec(dllimport)
#endif
#else
#define SAMPLE_LIBRARY_API
#endif

#endif /* EXPORT_MACROS_HPP */