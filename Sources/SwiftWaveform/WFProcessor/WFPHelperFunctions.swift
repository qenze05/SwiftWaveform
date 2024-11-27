import Foundation
import Accelerate

/**
 This class provides functions for transforming data
 # Available functions:
 - ``rms(data:frameLength:)``
 calculates and normalizes decibel value from  data
 - ``fft(data:setup:bufferSize:)``
 applies fast fourier transform to provided data and normalizes result
 - ``applyLogarithmicSpacing(fftMagnitudes:fs:nBands:fMin:fMax:smooth:)``
 applies logarithmic spacing for easier visualizing of data
 - ``halfSize(_:)``
 returns array half the size of the original by taking average of value pairs.
 */
public class WFPHelperFunctions {
    
    /**
     Calculates and normalizes decibel value from data.
     - Parameters:
        - data: the buffer’s audio samples as floating point values
        - frameLength: current number of valid sample frames in the buffer
     
     - Returns: float value in range (0...1)
     */
    public static func rms(data: UnsafeMutablePointer<Float>, frameLength: UInt) -> Float {
        var val: Float = 0
        vDSP_measqv(data, 1, &val, frameLength)
        
        var decibel = 10*log10f(val)
        decibel += 160
        // Only take range from 120 to 160
        decibel -= 120
        
        var adjustedVal = decibel/40
        
        if adjustedVal < 0.0 {
            adjustedVal = 0.0
        } else if adjustedVal > 1.0 {
            adjustedVal = 1.0
        }
        
        return adjustedVal
    }
    
    /**
     Applies fast fourier transform to provided data and normalizes result.
     - Parameters:
        - data: the buffer’s audio samples as floating point values
        - frameLength: current number of valid sample frames in the buffer
        - bufferSize: size of the buffer
     
     - Returns: array of float values. Values are normalized to (0...1) but could be higher than 1.
     */
    public static func fft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer, bufferSize: Int) -> [Float] {
        // output setup
        var realIn = [Float](repeating: 0, count: bufferSize)
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
        
        let sampleAmount = UInt(bufferSize/2)
        
        // fill in real input part with audio samples
        for ind in 0..<bufferSize {
            realIn[ind] = data[ind]
        }
        
        // fft
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        
        // setup magnitude output
        var magnitudes = [Float](repeating: 0, count: Int(sampleAmount))
        
        // calculate magnitude results
        realOut.withUnsafeMutableBufferPointer { realBP in
            imagOut.withUnsafeMutableBufferPointer { imagBP in
                guard let rbp = realBP.baseAddress, let ibp = imagBP.baseAddress else { return }
                var complex = DSPSplitComplex(realp: rbp, imagp: ibp)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, sampleAmount)
            }
        }
        
        // normalize
        var normalizedMagnitudes = [Float](repeating: 0.0, count: Int(sampleAmount))
        var scalingFactor: Float = (1 / log2(Float(bufferSize))) - (0.01 * (Float(bufferSize) / 1024))
        vDSP_vsmul(&magnitudes, 1, &scalingFactor, &normalizedMagnitudes, 1, sampleAmount)
        
        return normalizedMagnitudes
    }
    
    /**
     Applies logarithmic spacing to provided array of magnitudes and smoothes values if needed. Used for visualization purposes.
     - Parameters:
        - fftMagnitudes: array of magnitudes to apply function to
        - frequency: sampling frequency
        - nBands: size of result array
        - fMin: min frequency to take from input
        - fMax: max frequency to take from input, frequency/2 if nil
        - smooth: smooth kernel, must be higher than 1
     
     - Returns: array of nBands size with edited values.
     */
    public static func applyLogarithmicSpacing(
                                        fftMagnitudes: [Float],
                                        frequency: Float = 44100,
                                        nBands: Int = 10,
                                        fMin: Float = 20,
                                        fMax: Float? = nil,
                                        smooth: Int? = nil) -> [Float] {
        
        let maxF = frequency / 2
        let minF = min(max(20, fMin), frequency / 2 - 1)
        let numBins = fftMagnitudes.count
        let frequencyResolution = frequency / Float(fftMagnitudes.count * 2)
        let maxFrequency = min(fMax ?? maxF, maxF)
        
        // Apply spacing
        var bandEdges: [Float] = []
        for ind in 0...nBands {
            let exponent = Float(ind) / Float(nBands)
            let edgeFrequency = minF * pow((maxFrequency / minF), exponent)
            bandEdges.append(edgeFrequency)
        }

        // Fill result array with sums of ranges
        var bandMagnitudes = [Float](repeating: 0, count: nBands)
        let half = nBands / 2
        for band in 0..<nBands {
            let fStart = bandEdges[band]
            let fEnd = bandEdges[band + 1]
            
            // Find the indices of bins within the current frequency band
            let startIndex = max(Int(fStart / frequencyResolution), 0)
            let endIndex = min(Int(fEnd / frequencyResolution), numBins - 1)
            if startIndex <= endIndex {
                let binRange = startIndex...endIndex
                let magnitudesInBand = Array(fftMagnitudes[binRange])
                
                var sum: Float = 0
                vDSP_sve(magnitudesInBand, 1, &sum, vDSP_Length(magnitudesInBand.count))
                
                bandMagnitudes[band] =
                band < (half)
                ? (sum / 75)
                : (sum / sqrtf(Float(magnitudesInBand.count)) / 25)
            }
        }
        
        if let smooth, smooth > 1 && smooth <= bandMagnitudes.count {
            let half = smooth / 2
            
            let padded =
            [Float](repeating: bandMagnitudes.first ?? 0, count: half) +
            bandMagnitudes +
            [Float](repeating: bandMagnitudes.last ?? 0, count: half)
            
            var smoothedValues = [Float](repeating: 0, count: bandMagnitudes.count)
            
            let kernel = [Float](repeating: 1.7 / Float(smooth), count: smooth)
            
            vDSP_conv(padded, 1, kernel, 1, &smoothedValues, 1,
                      vDSP_Length(smoothedValues.count),
                      vDSP_Length(kernel.count))
            
            return smoothedValues
        }
        return bandMagnitudes
    }
    
    /**
     Makes array 2 times smaller by taking average of next value.
     
     - Parameters:
        - array: array to modify
     
     - Returns: array of size (inputArray.count / 2)
     */
    public static func halfSize(_ array: [Float]) -> [Float] {
        
        let newSize = array.count / 2
        var reducedArray = [Float](repeating: 0, count: newSize)
        
        array.withUnsafeBufferPointer { bufferPointer in
            let arrayPointer = bufferPointer.baseAddress!
            vDSP_vadd(arrayPointer, 2, arrayPointer + 1, 2, &reducedArray, 1, vDSP_Length(newSize))
        }
        
        var result = [Float](repeating: 0, count: newSize)
        var scalingFactor: Float = 1/2
        vDSP_vsmul(&reducedArray, 1, &scalingFactor, &result, 1, vDSP_Length(newSize))
        
        return result
    }
}
