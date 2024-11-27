Pod::Spec.new do |spec|
  spec.name         = "SwiftWaveform"
  spec.version      = "0.0.5"
  spec.summary      = "Swift framework for audio visualization on iOS platform."
  spec.description  = <<-DESC
    SwiftWaveform is a Swift framework for audio visualization on iOS platform. It provides customizable and lightweight waveform views that can be integrated into your iOS applications using UIKit or SwiftUI.
  DESC
  spec.homepage     = "https://github.com/qenze05/SwiftWaveform"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Oleksandr Kataskin" => "zespees@gmail.com" }
  spec.source       = { :git => "https://github.com/qenze05/SwiftWaveform.git", :tag => "#{spec.version}" }
  
  spec.platform     = :ios, "13.0"

  spec.swift_versions = ["5.0"]

  spec.source_files  = "Sources/SwiftWaveform/**/*.{swift}"
end
