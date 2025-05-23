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
  
  # Include the required frameworks
  s.vendored_frameworks = [
    'libsample_library.xcframework',
    'ThermalSDK.xcframework',
    'MeterLink.xcframework'
  ]

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'  # Update to match the deployment target in make_iOS.sh

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  
  s.swift_version = '5.0'
  s.frameworks = 'AVFoundation', 'UIKit', 'Foundation', 'CoreFoundation', 'AudioToolbox', 'VideoToolbox', 'CoreMedia', 'CoreVideo', 'ThermalSDK', 'MeterLink'
  s.libraries = 'iconv'
end
