import Foundation
import AVFoundation

/// Plays the looping chime and fades its volume in gradually, driving the "sanft beginnen,
/// langsam lauter werden" (start soft, get gradually louder) part of the alarm.
final class AlarmAudioPlayer: ObservableObject {

    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?

    /// Starts looping the chime at volume 0 and ramps it up to `peakVolume` linearly
    /// over `rampSeconds`, then holds at peak until `stop()` is called.
    func start(rampSeconds: Double, peakVolume: Float = 0.9) {
        stop()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            // Continue anyway; playback will just be subject to the ring/silent switch.
        }

        guard let url = Bundle.main.url(forResource: "Chime", withExtension: "wav") else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()
        self.player = player
        isPlaying = true

        let steps = 100
        let stepDuration = max(rampSeconds, 0.1) / Double(steps)
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self, let player = self.player else {
                timer.invalidate()
                return
            }
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            player.volume = min(peakVolume, peakVolume * progress)
            if currentStep >= steps {
                timer.invalidate()
            }
        }
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
