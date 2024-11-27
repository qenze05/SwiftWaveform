import Foundation
import Accelerate
import AVFoundation

/**
 This class provides audio frequency analyzer and simple audio player.
 
 # Frequency data
 ## fftMagnitudes
 Float array of frequency magnitudes. Normalized to range (0...1), though values can be higher than 1.
 ## rmsValue
 Float value of audio loudness. Normalized to range (0...1).
 
 # Audio player
 Simple AVAudioEngine player that uses AVAudioPlayerNode.
 ## Available functions
 -  ``play()`` - either pause or resume audio
 -  ``pause()`` - force pause of audio
 -  ``seekTo(_:)`` - play audio at provided time in seconds
 -  ``stopEngine()`` - stop engine and remove all taps.
 
 > Important: Do not use player function after calling ``stopEngine()``. You need to setup engine first.
 
 # Engine setup
 - ``setupInput(_:)`` - setup new input for engine
 - ``setupSettings(_:)`` - setup new settings for engine
 
 # Other data:
 ## state
 State of processor player. See ``WFProcessorState``
 ## audioLength
 Length of currently playing audio in seconds. Doesn't update on mic input.
 ## currentTime
 Progress of currently playing song in seconds. Doesn't update on mic input.
 */
class WFProcessor {
    
    public private(set) var state: WFProcessorState = .paused

    private var settings: WFProcessorSettings
    
    private var engine: AVAudioEngine
    private var player: AVAudioPlayerNode
    
    private var frequency: Float
    private var mixerNode: AVAudioMixerNode?
    private var fftSetup: vDSP_DFT_Setup?
    private var bufferSize: Int
    
    private var lastPlayedTime: TimeInterval
    private var audioFile: AVAudioFile?
    
    public private(set) var audioLength: TimeInterval
    public private(set) var currentTime: TimeInterval
    public private(set) var fftMagnitudes: [Float]
    public private(set) var rmsValue: Float
    
    /**
     Initializes new WFProcessor with provided settings
     - Parameters:
        - settings: processor settings, see ``WFProcessorSettings``
    */
    init(settings: WFProcessorSettings) {
        self.settings = settings

        self.engine = AVAudioEngine()
        self.player = AVAudioPlayerNode()
        
        self.bufferSize = settings.bufferSize
        self.fftMagnitudes = Array(repeating: 0, count: bufferSize / 2)
        self.frequency = 44100
        self.rmsValue = 0
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(bufferSize), vDSP_DFT_Direction.FORWARD)
        
        self.currentTime = 0
        self.audioLength = 0
        self.lastPlayedTime = 0
                
        setupInput()
    }
    
    /**
     Calls ``resume()`` if state is paused, calls ``pause()`` otherwise.
     */
    public func play() {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Failed to start engine: \(error.localizedDescription)")
                return
            }
        }
        switch state {
        case .playing:
            pause()
        case .paused:
            resume()
        }
    }
    
    private func resume() {
        switch settings.inputType {
        case .mic:
            break
        default:
            player.play()
        }
        state = .playing
    }
    
    /**
     Pauses engine if inputType is mic, pauses player if inputType is file or url.
     */
    public func pause() {
        switch settings.inputType {
        case .mic:
            engine.pause()
        default:
            player.pause()
        }
        state = .paused
    }
    
    /**
     Plays audio from provided time in seconds
     - Parameters:
        - time: time in seconds to play from. Cannot be less than zero and more than audioLength.
     */
    public func seekTo(_ time: TimeInterval) {
        switch settings.inputType {
        case .mic:
            return
        default:
            guard
                time >= 0 && time < audioLength,
                let audioFile = audioFile,
                player.isPlaying || state != .playing
            else { return }
            
            player.stop()

            currentTime = time
            lastPlayedTime = currentTime
            let newTime = AVAudioFramePosition(time * Double(frequency))

            player.scheduleSegment(audioFile,
                                   startingFrame: newTime,
                                   frameCount: AVAudioFrameCount(audioFile.length - newTime),
                                   at: nil,
                                   completionHandler: audioEndedHandler)
            
            player.play()
        }
    }
    
    /**
     Stops engine and removes taps from nodes.
     > Important: Do not use player function after calling ``stopEngine()``. You need to setup engine first.
     */
    public func stopEngine() {
        engine.mainMixerNode.removeTap(onBus: 0)
        mixerNode?.removeTap(onBus: 0)
        engine.stop()
        state = .paused
    }
    
    private func updateTime() {
        guard state == .playing, let audioFile else { return }
        
        if let nodeTime = player.lastRenderTime,
           let playerTime = player.playerTime(forNodeTime: nodeTime) {
            currentTime = lastPlayedTime + Double(playerTime.sampleTime) / audioFile.processingFormat.sampleRate
            if currentTime >= audioLength {
                audioEndedHandler()
            }
        }
    }
    
    @objc
    private func audioEndedHandler() {
        if currentTime >= audioLength {
            stopEngine()
            lastPlayedTime = 0
            currentTime = 0
        }
    }
    
    private func resetProcessor() {
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        
        bufferSize = settings.bufferSize
        fftMagnitudes = Array(repeating: 0, count: bufferSize / 2)
        frequency = 44100
        rmsValue = 0
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(bufferSize), vDSP_DFT_Direction.FORWARD)
        
        currentTime = 0
        audioLength = 0
        lastPlayedTime = 0
        
        audioFile = nil
        
        state = .paused
    }
    
    /**
     Setup new input for processor. It's safe to use player functions afterwards.
     - Parameters:
        - inputType: new input, see ``WFInputType``
     */
    public func setupInput(_ inputType: WFInputType) {
        stopEngine()
        settings.inputType = inputType
        resetProcessor()
        setupInput()
    }
    
    /**
     Setup new settings for processor. It's safe to use player functions afterwards.
     - Parameters:
        - settings: new settings, see ``WFProcessorSettings``
     */
    public func setupSettings(_ settings: WFProcessorSettings) {
        stopEngine()
        self.settings = settings
        resetProcessor()
        setupInput()
    }
    
    private func setupInput() {
        
        // Initialize mainMixerNode
        _ = engine.mainMixerNode
        
        var micSettings: WFMicSettings?
        let format: AVAudioFormat
        
        switch settings.inputType {
        case .mic(let settings):
            micSettings = settings
            do {
                // Setup session to record mic
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                
                // Grant access to mic
                var granted = false
                AVAudioApplication.requestRecordPermission { isGranted in
                    granted = isGranted
                }
                
                if !granted {
                    print("Microphone access not granted")
                    return
                }
            } catch {
                print("Failed to set up audio session: \(error.localizedDescription)")
                return
            }
            
        case .url(let url):
            // Get audio file from url
            do {
                audioFile = try AVAudioFile(forReading: url)
            } catch {
                print(error.localizedDescription)
                return
            }
            
        case .file(let file):
            audioFile = file
        }
        
        if let audioFile { // File or url case
            format = audioFile.processingFormat
            frequency = Float(audioFile.processingFormat.sampleRate)
            audioLength = audioFile.length > 0 ? Double(audioFile.length) / audioFile.processingFormat.sampleRate : 0
            
            // Attach and connect node to engine
            engine.attach(player)
            engine.connect(player,
                           to: engine.mainMixerNode,
                           format: format)
            
            // Schedule the playing of audio file
            player.scheduleFile(audioFile, at: nil, completionHandler: audioEndedHandler)
            
            // Install tap to process buffer
            engine.mainMixerNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: nil) {[weak self] (buffer, _) in
                guard let self else { return }
                self.processAudioData(buffer: buffer)
                self.updateTime()
            }
            
        } else { // Mic
            guard let micSettings else { return }
            
            // Mixer node for mic input node
            let mixerNode = AVAudioMixerNode()
            
            // Apply settings and attach
            mixerNode.outputVolume = micSettings.outputVolume
            engine.attach(mixerNode)
            
            // Mic input node
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            // Connect input node to mixer
            engine.connect(inputNode,
                           to: mixerNode,
                           format: inputFormat)
            
            let mixerFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: inputFormat.sampleRate,
                channels: 1,
                interleaved: false
            )
            
            engine.connect(mixerNode,
                           to: engine.mainMixerNode,
                           format: mixerFormat)
            
            let tapNode: AVAudioNode = mixerNode
            let tapNodeFormat = tapNode.outputFormat(forBus: 0)
            
            // Setup output file if needed
            var outputFile: AVAudioFile?
            if let directory = micSettings.outputDirectoryURL {
                let dateF = DateFormatter()
                dateF.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                let date = dateF.string(from: Date())
                let fileName = "\(micSettings.outputName ?? "recording")\(date).caf"
                let outputFileURL = directory.appendingPathComponent(fileName)
                do {
                    outputFile = try AVAudioFile(
                        forWriting: outputFileURL,
                        settings: tapNodeFormat.settings)
                } catch {
                    print("Failed to create file \(outputFileURL): \(error.localizedDescription)")
                    return
                }
                
            }
            
            // Install tap to process buffer
            tapNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: tapNodeFormat, block: {[weak self] (buffer, _) in
                guard let self else {return}
                self.processAudioData(buffer: buffer)
                try? outputFile?.write(from: buffer)
            })
            
        }
        engine.prepare()
    }
    
    private func processAudioData(buffer: AVAudioPCMBuffer) {
        if state != .playing {
            return
        }
        
        guard let channelData = buffer.floatChannelData?[0] else {return}
        
        switch settings.processingType {
        case .all:
            rmsValue = WFPHelperFunctions.rms(data: channelData, frameLength: UInt(buffer.frameLength))
            fftMagnitudes = WFPHelperFunctions.fft(data: channelData, setup: fftSetup!, bufferSize: bufferSize)
        case .volume:
            rmsValue = WFPHelperFunctions.rms(data: channelData, frameLength: UInt(buffer.frameLength))
        case .fft:
            fftMagnitudes = WFPHelperFunctions.fft(data: channelData, setup: fftSetup!, bufferSize: bufferSize)
        }
        
    }
}
