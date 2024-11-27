# SwiftWaveform

![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

SwiftWaveform is a Swift framework for audio visualization on iOS platform. It provides customizable and lightweight waveform views that can be integrated into your iOS applications using UIKit or SwiftUI.

## Features

- **Real-Time Audio Visualization**: Visualize audio data in real-time using FFT or RMS models. Prepare data for visualization using other helper functions.
- **Customizable Waveform Style**: Bar and circular waveform styles, multiple color modes, mirror mode and other customizations.
- **Animation Control**: Customizable animation duration and timing function.
- **Easy Configuration**: Flexible settings with preset values for simple or advanced configuration.
- **SwiftUI Support**: SwiftUI view wrapper for easier integration. 

## Installation

### Swift Package Manager

You can add **SwiftWaveform** to your Xcode project using Swift Package Manager:

1. **File > Add Packages...**
2. Enter repository URL: `https://github.com/qenze05/SwiftWaveform.git`.
3. Select version and click "Add Package".

### CocoaPods

Add pod to `Podfile`:
```ruby 
pod 'SwiftWaveform'
```

Install pod:
```bash 
pod install
```

## Usage

### Importing the framework
```swift 
import SwiftWaveform
```

### Using WFProcessor for getting fft and rms data
1. Initialize WFProcessor
```swift 
let audioProcessing = WFProcessor(
    settings: WFProcessorSettings(
        inputType: .mic(WFMicSettings(outputVolume: 0.5, outputURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])),
        processingType: .all,
        bufferSize: 4096))
```
2. Update your values using processor data
```swift 
func updateData(_: Date) {
    //simply getting fft
    data = audioProcessing.fftMagnitudes
    
    //applying helper function for better visualization
    data = WFPHelperFunctions.applyLogarithmicSpacing(
        fftMagnitudes: audioProcessing.fftMagnitudes,
        nBands: K.limit,
        fMin: 40,
        fMax: 10000,
        smooth: 5
    )
    
    //getting rms value
    rms = audioProcessing.rmsValue
}
```

### Controlling playback using WFProcessor
```swift
// play 5 second earlier
audioProcessing.seekTo(audioProcessing.currentTime - 5)

// set new audio
audioProcessing.setupInput(.url(songURL))

// play and stop audio
audioProcessing.play()
```

### Creating and configuring view

UIKit:
1. Create settings configuration
```swift
let settings = WFViewSettings(
                    frameTime: K.time,
                    barCount: K.limit,
                    modelType: .fft,
                    viewType: .circle(WFCircleViewSettings(radius: 0.5, barWidth: 2)),
                    colorSettings: WFColorSettings(bgColor: .black, colorMode: .gradientAllBars(colors: [.red, .yellow], mirrored: true)),
                    maxHeight: 1,
                    mirrored: true,
                    drawSilence: true
                )
```
2. Create view
```swift
let view = WaveformView()
view.configure(settings: settings)
```
3. Setup view when bounds are initialized
```swift
if !view.isSetUp && view.bounds.width != 0 {
    view.setupView()
}
```
4. Provide data for visualization
```swift
if settings.modelType == .rms {
    view.setRMS(rms)
} else {
    view.setFFT(frequencies)
}
```

SwiftUI:
1. Create settings configuration
2. Create view using bindings and settings
```swift
WaveformViewSUI(
    frequencies: $fft,
    rms: $rms,
    settings: settings)
```


## Requirements
iOS 13.0+
Swift 5.0+

## License
SwiftWaveform is available under the MIT License.



