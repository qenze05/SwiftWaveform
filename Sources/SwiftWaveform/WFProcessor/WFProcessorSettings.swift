import Foundation
import AVFoundation

/**
 Settings of ``WFProcessor``
 - Parameters:
    - inputType: mic, url or file input type, see ``WFInputType``
    - processingType:volume, fft or both, see ``WFProcessType``
    - bufferSize: size of buffer to use. 4096 recommended, lower to 2048 or 1024 if needed.
 */
public class WFProcessorSettings {
    public var inputType: WFInputType
    public var processingType: WFProcessType
    public var bufferSize: Int
    
    public init(inputType: WFInputType, processingType: WFProcessType, bufferSize: Int = 4096) {
        self.inputType = inputType
        self.processingType = processingType
        self.bufferSize = bufferSize
    }
}

/**
 Types of data to process, see ``WFPHelperFunctions``
 */
public enum WFProcessType {
    case all
    case volume
    case fft
}

/**
 Type of input. Either url of file on drive, file itself or mic input.
 For mic settings see ``WFMicSettings``
 */
public enum WFInputType {
    case mic(WFMicSettings)
    case url(URL)
    case file(AVAudioFile)
}

/**
 Settings for mic input.
 - Parameters:
    - outputVolume: value in 0...1 range
    - outputURL: url of directory where file from input will be written. File is not recorded without outputURL.
    - outputName: prefix for output file. Needed if outputURL is present.
 */
public struct WFMicSettings {
    public let outputVolume: Float
    public let outputDirectoryURL: URL?
    public let outputName: String?
    
    public init(outputVolume: Float = 0.0, outputURL: URL? = nil, outputName: String? = nil) {
        self.outputVolume = max(0, min(outputVolume, 1))
        self.outputDirectoryURL = outputURL
        self.outputName = outputName
    }
}

/**
 State of processor. Can be playing or paused.
 */
public enum WFProcessorState {
    case playing
    case paused
}
