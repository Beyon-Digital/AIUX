require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'AIUXExpo'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = 'MIT'
  s.author         = 'Beyon Digital'
  s.homepage       = 'https://github.com/Beyon-Digital/AIUX'
  s.platforms      = { :ios => '16.0' }
  s.swift_version  = '5.9'
  s.source         = { git: 'https://github.com/Beyon-Digital/AIUX.git', tag: "v#{package['version']}" }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # The vendored core: `AiuxSession` (UniFFI) + `AIUXCoreFFI` Rust static lib,
  # staged by `scripts/prepare-ios.sh` into ios/vendor/. The SwiftUI renderer
  # and generated UniFFI binding compile into this pod so the module boundary
  # stays JSON-only end to end (plan §10, ADR 0005).
  s.vendored_frameworks = 'vendor/AIUXCore.xcframework'

  # source_files must live under this pod root — prepare-ios.sh stages the
  # renderer + generated UniFFI binding into vendor/staged/.
  s.source_files = [
    'Sources/**/*.swift',
    'vendor/staged/**/*.swift',
  ]

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
  }
end
