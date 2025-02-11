import 'dart:ffi';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:ffi/ffi.dart';

import 'blabla_bindings_generated.dart';

const String _libName = 'blabla';

/// The dynamic library in which the symbols for [blablaBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final blablaBindings _bindings = blablaBindings(_dylib);

final class SampleLib {
  const SampleLib._();

  static int sum(int a, int b) => _bindings.sum(a, b);
  static String getVersion() =>
      _bindings.getVersion().cast<Utf8>().toDartString();
  static int factorial(int input) => _bindings.factorial(input);
  static void processImage() {
    final width = 5;
    final height = 5;
    final channels = 4; // RGBA

    final inputPointer = malloc<Uint8>(width * height * channels);
    final outputPointer = malloc<Uint8>(width * height * channels);

    // Copy input bytes to native memory
    for (var i = 0; i < width * height * channels; i++) {
      inputPointer[i] = Random().nextInt(256);
    }

    // Process the image
    _bindings.process_image(
      inputPointer,
      width,
      height,
      channels,
      outputPointer,
    );

    // Free native memory
    malloc.free(inputPointer);
    malloc.free(outputPointer);
  }
}
