import AVFoundation
import Foundation

/// Live RMS meter over the tap. Feeds the blob reactivity and the segmenter.
final class AudioLevelMeter {
    private(set) var level: Double = 0
    private var window: [Double] = []

    func process(buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Double = 0
        for i in 0..<n {
            let v = Double(channel[i])
            sum += v * v
        }
        let rms = (sum / Double(n)).squareRoot()
        let db = 20 * log10(max(rms, 1e-8))
        let normalized = max(0, min(1, (db + 50) / 40))
        window.append(normalized)
        if window.count > 8 { window.removeFirst() }
        level = window.reduce(0, +) / Double(window.count)
        return level
    }
}