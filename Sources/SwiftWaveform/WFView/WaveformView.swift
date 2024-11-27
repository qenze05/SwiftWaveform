import UIKit

/**
 View that shows waveform in form of bars or circle.
 
 # Steps to configure
 - apply settings using view.configure(settings:)
 - setup using view.setup() afters view bounds are calculated
 - setup updates on data change using view.setRMS(_:) or view.setFFT(_:)
 
 # Available data:
 - isSetUp - boolean value, true after successful call of setupView()
 - frequencyValues - float array, data used for creating waveform view
 */
public class WaveformView: UIView {
    
    public private(set) var isSetUp = false
    
    public private(set) var frequencyValues: [Float] = []
    
    private var barLayers: [CAShapeLayer] = []
    private var settings: WFViewSettings?
    
    /**
     Updates data using FFT values. Animates transition from old values to new.
     - Parameters:
        - frequency: array of data to replace existing one
     */
    public func setFFT(_ frequency: [Float]) {
        if frequencyValues.count != frequency.count || settings?.modelType == .rms { return }
        frequencyValues = frequency
        animate(to: frequencyValues)
    }
    
    /**
    Updates data using rms value. Appends data array and shifts older values. Animated transition from old values to new.
     - Parameters:
        - amp: rms value that will be appended to array
     */
    public func setRMS(_ amp: Float) {
        if settings?.modelType == .fft { return }
        self.frequencyValues.append(amp)
        self.frequencyValues.removeFirst()
        animate(to: frequencyValues)
    }
    
    /**
     Function for view configuration. Applies settings and initializes data array.
     - Parameters:
        - settings: settings to apply, see ``WFViewSettings``
     */
    public func configure(settings: WFViewSettings) {
        self.settings = settings
        self.frequencyValues = [Float](repeating: 0, count: settings.barCount)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setupView()
    }
    
    /**
     Function for view setup. Must be called after applying settings and initializing view bounds.
     */
    public func setupView() {
        guard let settings, bounds.width != 0, bounds.height != 0 else { return }
        
        frequencyValues = [Float](repeating: 0, count: settings.barCount)
        
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers = []
        
        backgroundColor = settings.colorSettings.bgColor
        
        var barWidth: CGFloat?
        
        for ind in 0..<settings.barCount {
            
            let barLayer = CAShapeLayer()
            var color: UIColor?
            switch settings.colorSettings.colorMode {
            case .solidColor(let col):
                color = col
            case .solidColors(let colors, let mirrored):
                var gColors = colors
                if mirrored {
                    colors.forEach {gColors.insert($0, at: colors.endIndex)}
                }
                color = colorFromGradient(colors: gColors, value: (CGFloat(ind) / (CGFloat(settings.barCount) - 1)), solid: true)
            case .gradientAllBars(let colors, let mirrored):
                var gColors = colors
                if mirrored {
                    colors.forEach {gColors.insert($0, at: colors.endIndex)}
                }
                color = colorFromGradient(colors: gColors, value: (CGFloat(ind) / (CGFloat(settings.barCount) - 1)))
            default:
                break
            }
            
            if let color {
                barLayer.fillColor = color.cgColor
                barLayer.strokeColor = color.cgColor
            }
            
            let barPath = UIBezierPath()
            
            switch settings.viewType {
            case .bar(let setts):
                if barWidth == nil {
                    barWidth = (bounds.width - setts.barSpacing * CGFloat(settings.barCount - 1)) / CGFloat(settings.barCount)
                }
                guard let barWidth else { return }
                
                let xCoord = CGFloat(ind) * (barWidth + setts.barSpacing)
                let barRect = CGRect(x: xCoord, y: 0, width: barWidth, height: bounds.height)
                let pathRect = CGRect(x: 0, y: setts.twoSided ? bounds.height / 2 : 0, width: barWidth, height: 0)
                
                barLayer.frame = barRect
                barLayer.path = UIBezierPath(rect: pathRect).cgPath
            case .circle(let setts):
                let radius = setts.radius * (min(bounds.height, bounds.width) / 2)
                let angle = CGFloat(ind) * (2 * .pi / CGFloat(settings.barCount))
                
                let startX = bounds.midX + cos(angle) * radius
                let startY = bounds.midY + sin(angle) * radius
                
                let mult = settings.drawSilence ? radius + 3 : radius
                let endX = bounds.midX + cos(angle) * mult
                let endY = bounds.midY + sin(angle) * mult
                
                barPath.move(to: CGPoint(x: startX, y: startY))
                barPath.addLine(to: CGPoint(x: endX, y: endY))
                
                barLayer.lineWidth = setts.barWidth
                barLayer.path = barPath.cgPath
                
                if let circleFillColor = setts.circleFillColor {
                    let circleLayer = CAShapeLayer()
                    
                    let circlePath = UIBezierPath(
                        arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                        radius: radius,
                        startAngle: 0,
                        endAngle: 2 * .pi,
                        clockwise: true
                    )
                    
                    circleLayer.path = circlePath.cgPath
                    circleLayer.fillColor = circleFillColor.cgColor
                    
                    layer.addSublayer(circleLayer)
                }
            }
            
            layer.addSublayer(barLayer)
            barLayers.append(barLayer)
        }
        
        isSetUp = true
    }
    
    private func getBarPath(index: Int, barLayer: CALayer, length: CGFloat) -> UIBezierPath? {
        guard
            let settings,
            case let .bar(setts) = settings.viewType
        else { return nil }
        
        let yCoord = setts.twoSided ? bounds.height / 2 - length / 2 : bounds.height - length
        
        let pathRect = CGRect(
            x: 0,
            y: yCoord,
            width: barLayer.frame.width,
            height: length
        )
        let result: UIBezierPath
        if setts.roundCorners {
            result = UIBezierPath(roundedRect: pathRect, cornerRadius: pathRect.width / 2)
        } else {
            result = UIBezierPath(rect: pathRect)
        }
        return result
    }
    
    private func getCirclePath(index: Int, barLayer: CALayer, length: CGFloat) -> UIBezierPath? {
        guard
            let settings,
            case let .circle(setts) = settings.viewType
        else { return nil }
        
        let radius = setts.radius * (min(bounds.height, bounds.width) / 2)
        
        var barLength = length
        
        if !settings.drawSilence || length > 3 {
            barLength /= 2
            barLength *= (1 - setts.radius)
        }
        
        let angle = CGFloat(index) * (2.0 * .pi / CGFloat(settings.barCount)) - (.pi / 2)
        let startX = bounds.midX + cos(angle) * radius
        let startY = bounds.midY + sin(angle) * radius
        
        let endX = bounds.midX + cos(angle) * (radius + barLength)
        let endY = bounds.midY + sin(angle) * (radius + barLength)
        
        let newPath = UIBezierPath()
        
        newPath.move(to: CGPoint(x: startX, y: startY))
        newPath.addLine(to: CGPoint(x: endX, y: endY))
        
        return newPath
    }
    
    private func animate(to values: [Float]) {
        guard values.count == barLayers.count else {
            print("Mismatch count between prodived values (\(values.count)) and bars (\(barLayers.count))")
            return
        }

        guard let settings, isSetUp else {return}

        let vals: [Float]
        if settings.mirrored {
            vals = WFPHelperFunctions.halfSize(values)
        } else {
            vals = values
        }

        let lengthMultiplier: CGFloat
        switch settings.viewType {
        case .bar:
            lengthMultiplier = (bounds.height * settings.maxHeight)
        case .circle:
            lengthMultiplier = (min(bounds.height, bounds.width) * settings.maxHeight)
        }
        
        for (index, barLayer) in barLayers.enumerated() {
            let val: CGFloat
            
            if settings.mirrored && index >= vals.count {
                val = CGFloat(vals[values.count - 1 - index])
            } else {
                val = CGFloat(vals[index])
            }
            
            let magnitude = min(val, 1)
            
            var newPath: UIBezierPath
            var barLength: CGFloat
            switch settings.viewType {
            case .bar:
                barLength = magnitude * lengthMultiplier
                if settings.drawSilence && barLength <= 3 { barLength = 3 }
                if let path = getBarPath(index: index, barLayer: barLayer, length: barLength) {
                    newPath = path
                } else {
                    return
                }
            case .circle:
                barLength = magnitude * lengthMultiplier
                if settings.drawSilence && barLength <= 3 { barLength = 3 }
                if let path = getCirclePath(index: index, barLayer: barLayer, length: barLength) {
                    newPath = path
                } else {
                    return
                }
            }
            
            var color: UIColor?
            switch settings.colorSettings.colorMode {
            case .gradientSingularBar(let colors):
                color = colorFromGradient(colors: colors, value: magnitude)
            default:
                break
            }
            
            if let color {
                barLayer.fillColor = color.cgColor
                barLayer.strokeColor = color.cgColor
            }
            
            var dur = settings.animation.duration
            // avoid calling completion block after next animateBars is called
            if settings.frameTime == dur && dur > 0 {
                dur -= 0.01
            } else if dur > settings.frameTime {
                dur = settings.frameTime - 0.01
            } else if dur < 0 {
                dur = 0
            }
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = barLayer.path
            animation.toValue = newPath.cgPath
            animation.duration = dur
            animation.timingFunction = settings.animation.timingFunction
            
            CATransaction.begin()
            
            if settings.modelType != .rms || index == barLayers.count - 1 {
                barLayer.add(animation, forKey: "pathAnimation")
            }
            
            CATransaction.setCompletionBlock {
                barLayer.path = newPath.cgPath
            }
            
            CATransaction.commit()
        }
    }
    
    private func colorFromGradient(colors: [UIColor], value: CGFloat, solid: Bool = false) -> UIColor {
        
        let segment = solid
        ? value * CGFloat(colors.count)
        : value * CGFloat(colors.count - 1)
        
        let index = Int(segment)
        
        if index >= colors.count - 1 {
            return colors.last ?? .white
        }
        
        let color1 = colors[index]
        
        if solid { return color1 }
        
        let color2 = colors[index + 1]
        
        return interpolateColor(color1: color1, color2: color2, fraction: segment - CGFloat(index))
    }
    
    private func interpolateColor(color1: UIColor, color2: UIColor, fraction: CGFloat) -> UIColor {
        var rVal1: CGFloat = 0
        var gVal1: CGFloat = 0
        var bVal1: CGFloat = 0
        var aVal1: CGFloat = 0
        
        color1.getRed(&rVal1, green: &gVal1, blue: &bVal1, alpha: &aVal1)
        
        var rVal2: CGFloat = 0
        var gVal2: CGFloat = 0
        var bVal2: CGFloat = 0
        var aVal2: CGFloat = 0
        
        color2.getRed(&rVal2, green: &gVal2, blue: &bVal2, alpha: &aVal2)
        
        let rVal = rVal1 + (rVal2 - rVal1) * fraction
        let gVal = gVal1 + (gVal2 - gVal1) * fraction
        let bVal = bVal1 + (bVal2 - bVal1) * fraction
        let aVal = aVal1 + (aVal2 - aVal1) * fraction
        
        return UIColor(red: rVal, green: gVal, blue: bVal, alpha: aVal)
    }
}
