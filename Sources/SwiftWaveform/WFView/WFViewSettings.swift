import Foundation
import UIKit

/**
 Settings for ``WaveformView``
 - Parameters:
    - frameTime: time between data updates. 0.1 recommended since processor update rate is roughly 0.11 seconds.
    - barCount: number of bars to draw, minimum value is 2
    - viewType: bars or circular view, see ``WFViewType``
    - modelType: type of data to present, can be fft or rms (volume).
    - colorSettings: colors settings for view, see ``WFColorSettings``
    - maxHeight: max height of bars, can be in range 0...1
    - mirrored: applies mirror effect to presented data
    - drawSilence: draws 3-pixel bar when value is lower
    - animation: animation of bars, see ``WFAnimationSettings``
 */
public class WFViewSettings {
    var frameTime: TimeInterval
    var barCount: Int
    var viewType: WFViewType
    var modelType: WFModel
    var colorSettings: WFColorSettings
    var maxHeight: CGFloat
    var mirrored: Bool
    var drawSilence: Bool
    var animation: WFAnimationSettings
    
    init(frameTime: TimeInterval,
         barCount: Int,
         modelType: WFModel,
         viewType: WFViewType,
         colorSettings: WFColorSettings = WFColorSettings(),
         maxHeight: CGFloat = 1,
         mirrored: Bool = false,
         drawSilence: Bool = false,
         animation: WFAnimationSettings? = nil
    ) {
        self.frameTime = max(0, frameTime)
        self.barCount = max(2, barCount)
        
        self.modelType = modelType
        self.viewType = viewType
        self.colorSettings = colorSettings
        
        if maxHeight > 1 || maxHeight < 0 {
            self.maxHeight = 1
        } else {
            self.maxHeight = maxHeight
        }
        
        self.mirrored = mirrored
        self.drawSilence = drawSilence
        
        self.animation = animation ?? WFAnimationSettings(
            duration: frameTime,
            timingFunction: CAMediaTimingFunction(name: .easeOut))
    }
}

public enum WFModel {
    case fft
    case rms
}

/**
 Waveform view presentation type. Can be bars or circular.
 See ``WFBarViewSettings`` and ``WFCircleViewSettings``
 */
public enum WFViewType {
    case bar(WFBarViewSettings)
    case circle(WFCircleViewSettings)
}

/**
 Settings for bar waveform view.
 - Parameters:
    - twoSided: draws bars from middle point to top and bottom if true. Draws bars from bottom to top if false.
    - roundCorners: rounds corners of bars if true
    - barSpacing: spacing between bars, can be 0
 */
public struct WFBarViewSettings {
    var twoSided: Bool
    var roundCorners: Bool
    var barSpacing: CGFloat
    
    init(twoSided: Bool = false, roundCorners: Bool = false, barSpacing: CGFloat = 2) {
        self.twoSided = twoSided
        self.roundCorners = roundCorners
        self.barSpacing = max(0, barSpacing)
    }
}

/**
 Settings for circular waveform view.
 - Parameters:
    - radius: radius of inner circle, bars will be drawn from its perimeter. Can be in range 0...1.
    - barWidth: width of bars, minimum is 0.1.
    - circleFillColor: fill color for inner circle. Transperent if nil.
 */
public struct WFCircleViewSettings {
    var radius: CGFloat
    var barWidth: CGFloat
    var circleFillColor: UIColor?
    
    init(radius: CGFloat = 0.5, barWidth: CGFloat = 2, circleFillColor: UIColor? = nil) {
        if radius < 0 || radius > 1 {
            self.radius = 0.5
        } else {
            self.radius = radius
        }
        self.barWidth = max(0.1, barWidth)
        self.circleFillColor = circleFillColor
    }
}

/**
 Settings for waveform animation.
 - Parameters:
    - duration: duration of animation. Cannot be higher than frameTime.
    - timingFunction: timing function to apply.
 */
public struct WFAnimationSettings {
    var duration: TimeInterval
    var timingFunction: CAMediaTimingFunction
}

/**
 Settings for waveform color.
 - Parameters:
    - bgColor: view background color
    - colorMode: fill color for bars, see ``WFColorMode``
 */
public struct WFColorSettings {
    let bgColor: UIColor
    let colorMode: WFColorMode

    init(bgColor: UIColor = .clear, colorMode: WFColorMode = .solidColor(.systemBlue)) {
        self.bgColor = bgColor
        self.colorMode = colorMode
    }
}

/**
 Fill color for waveform bars.
 - solidColor applies single color to all bars
 - solidColors applies gradient with hard color edges to all bars
 - gradientSingularBar applies gradient to each bar depending on their amplitude value
 - gradientAllBars applies gradient with soft color edges to all bars
 */
public enum WFColorMode {
    case solidColor(UIColor)
    case solidColors(colors: [UIColor], mirrored: Bool)
    case gradientSingularBar(colors: [UIColor])
    case gradientAllBars(colors: [UIColor], mirrored: Bool)
}
