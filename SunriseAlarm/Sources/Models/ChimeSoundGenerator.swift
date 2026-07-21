import AVFoundation

/// Erzeugt einen sanften Glocken-/Chime-Klang rein im Code (kein
/// mitgeliefertes Audio-Asset nötig) und spielt ihn in einer Endlosschleife
/// ab. Die Lautstärke kann von außen langsam hochgefahren werden, damit der
/// Wecker "sanft" beginnt und stetig lauter wird.
final class ChimeSoundGenerator {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isRunning = false

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Startet die Endlosschleife des Chime-Sounds bei Lautstärke 0.
    /// Die tatsächliche Lautstärke steuerst du danach über `setVolume`.
    func start() throws {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        engine.mainMixerNode.outputVolume = 0
        try engine.start()

        let buffer = Self.makeChimeLoopBuffer()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
    }

    /// Lautstärke 0...1, wird sofort (ohne eigenes Fade) gesetzt -
    /// der sanfte Übergang wird von AlarmManager über viele kleine Schritte erzeugt.
    func setVolume(_ volume: Float) {
        engine.mainMixerNode.outputVolume = max(0, min(1, volume))
    }

    // MARK: - Sound generation

    /// Baut eine Buffer-Schleife: ein weicher Glockenschlag (mehrere
    /// gedämpfte Sinustöne übereinander) gefolgt von einer Stille-Pause,
    /// damit es wie ein ruhiges, wiederkehrendes Klingeln klingt.
    private static func makeChimeLoopBuffer() -> AVAudioPCMBuffer {
        let sampleRate = 44100.0
        let chimeDuration = 2.2
        let silenceDuration = 1.8
        let totalDuration = chimeDuration + silenceDuration
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        // Weicher Glockenklang: Grundton + zwei leise Obertöne, exponentiell abklingend.
        let partials: [(frequency: Double, amplitude: Double, decay: Double)] = [
            (523.25, 0.5, 1.6),   // C5, Grundton
            (784.0, 0.22, 1.1),   // G5, Oberton
            (1046.5, 0.12, 0.8)   // C6, Oberton
        ]

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var sample: Double = 0
            if t < chimeDuration {
                // Sanfter Attack in den ersten 60ms, danach exponentieller Decay.
                let attack = min(1.0, t / 0.06)
                for partial in partials {
                    let envelope = attack * exp(-t / partial.decay)
                    sample += partial.amplitude * envelope * sin(2 * .pi * partial.frequency * t)
                }
            }
            channel[frame] = Float(sample)
        }

        return buffer
    }
}
