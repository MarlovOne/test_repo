#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint blabla.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'blabla'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.vendored_frameworks = 'libsample_library.xcframework'
  s.vendored_libraries = [
     'dylibs/libavcodec.dylib',
     'dylibs/libavformat.dylib',
     'dylibs/libavfilter.dylib',
     'dylibs/libavdevice.dylib',
     'dylibs/libavutil.dylib',
     'dylibs/libswresample.dylib',
     'dylibs/libswscale.dylib',
     'dylibs/libatlas_c_sdk.dylib',
     'dylibs/libavcodec.58.dylib',
     'dylibs/libavdevice.58.dylib',
     'dylibs/libavfilter.7.dylib',
     'dylibs/libavformat.58.dylib',
     'dylibs/libavutil.56.dylib',
     'dylibs/libswresample.3.dylib',
     'dylibs/liblive666.dylib',
     'dylibs/libswscale.5.dylib'
   ]

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'blabla_privacy' => ['blabla/Sources/blabla/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.frameworks = 'AVFoundation', 'Foundation', 'CoreFoundation', 'CoreMedia'
end
