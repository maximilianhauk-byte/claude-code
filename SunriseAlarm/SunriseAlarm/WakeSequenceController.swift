import Foundation
import UIKit
import AVFoundation

/// Drives the actual "wake experience": a soft, bell-like tone that fades in
/// from silence, together with the screen brightness ramping up from near-zero
/// to full brightness over the same duration.
@MainActor
final class WakeSequenceController: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0 // 0...1

    private var displayTimer: Timer?
    private var startBrightness: CGFloat = 0.02
    private let targetBrightness: CGFloat = 1.0
    private var startDate: Date?
    private var duration: TimeInterval = 600
    private var targetVolume: Float = 0.8

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    /// Starts the fade-in sequence. `duration` is in seconds — use the real
    /// fade duration (e.g. 600s = 10 min) for the actual alarm, or a short
    /// value (e.g. 30s) to preview the effect instantly.
    func start(duration: TimeInterval, targetVolume: Float = 0.8) {
        stop()
        self.duration = max(duration, 1)
        self.targetVolume = targetVolume
        self.startDate = Date()
        self.isRunning = true
        self.progress = 0

        let current = UIScreen.main.brightness
        startBrightness = current > 0.15 ? 0.02 : current

        startTone()

        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        displayTimer?.invalidate()
        displayTimer = nil
        isRunning = false
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }

    private func tick() {
        guard let startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        let fraction = min(1.0, elapsed / duration)
        progress = fraction

        UIScreen.main.brightness = startBrightness + (targetBrightness - startBrightness) * CGFloat(fraction)
        playerNode?.volume = Float(fraction) * targetVolume

        if fraction >= 1.0 {
            displayTimer?.invalidate()
            displayTimer = nil
        }
    }

    private func startTone() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate = 44100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let buffer = Self.makeChimeBuffer(sampleRate: sampleRate, format: format)

        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        guard (try? engine.start()) != nil else { return }

        player.volume = 0
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()

        audioEngine = engine
        playerNode = player
    }

    /// Synthesizes a soft, bell-like looping tone (two mellow sine partials
    /// with a slow tremolo) — no bundled audio file needed.
    private static func makeChimeBuffer(sampleRate: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let loopSeconds = 4.0
        let frameCount = AVAudioFrameCount(sampleRate * loopSeconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        let f1 = 528.0
        let f2 = 660.0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let tremolo = 0.85 + 0.15 * sin(2 * .pi * 0.5 * t)
            let sample = (sin(2 * .pi * f1 * t) * 0.6 + sin(2 * .pi * f2 * t) * 0.3) * tremolo
            channel[i] = Float(sample * 0.5)
        }
        return buffer
    }
}
