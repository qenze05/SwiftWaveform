import Foundation
import SwiftUI

/**
 SwiftUI wrapper for ``WaveformView``
 - Parameters:
    - frequencies: binding of fft data, array of floats
    - rms: binding of rms data, float value
    - settings: waveform view settings, see ``WFViewSettings``
 */
public struct WaveformViewSUI: UIViewRepresentable {
    
    @Binding var frequencies: [Float]
    @Binding var rms: Float
    let settings: WFViewSettings
    
    // MARK: - UIViewRepresentable
    func makeUIView(context: Context) -> WaveformView {
        let view = WaveformView()
        view.configure(settings: settings)
        return view
    }
    
    func updateUIView(_ uiView: WaveformView, context: Context) {

        if !uiView.isSetUp && uiView.bounds.width != 0 {
            uiView.setupView()
        }
        if settings.modelType == .rms {
            uiView.setRMS(rms)
        } else {
            uiView.setFFT(frequencies)
        }
    }
    
}
