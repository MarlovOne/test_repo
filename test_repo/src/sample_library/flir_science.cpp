#include <fnvcam/fnvcam.h>

void exmaple()
{
  // Example usage of the FLIR Science SDK
  fnv::cam::CCamera camera;
  camera.Connect();
  camera.Disconnect();
}