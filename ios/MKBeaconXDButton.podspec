Pod::Spec.new do |s|
  s.name             = 'MKBeaconXDButton'
  s.version          = '1.0.0'
  s.summary          = 'MokoSmart BLE Button SDK (core only, no UI)'
  s.description      = 'Core BLE SDK for MK Button — UI classes excluded.'
  s.homepage         = 'https://github.com/BeaconX-Pro/14-iOS-MKButton-SDK'
  s.license          = { :type => 'MIT' }
  s.author           = { 'MokoSmart' => '' }
  s.platform         = :ios, '14.0'
  s.source           = {
    :git  => 'https://github.com/BeaconX-Pro/14-iOS-MKButton-SDK.git',
    :branch => 'Developer'
  }
  s.source_files        = 'MKBeaconXDButton/Classes/SDK/**/*.{h,m}'
  s.public_header_files = 'MKBeaconXDButton/Classes/SDK/**/*.h'
  s.compiler_flags   = '-Wno-return-type'
  s.frameworks       = 'CoreBluetooth', 'UIKit', 'Foundation'
  s.requires_arc     = true
  s.pod_target_xcconfig = { 'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES' }
end
