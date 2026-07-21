import AVFoundation
import Combine
import UIKit

/// Drives the actual "waking up" experience: a looping chime that fades in
/// from silence, and the screen brightness ramping up alongside it, over
/// `rampDuration` seconds.
final class AlarmPlayer: NSObject, ObservableObject {
    @Published private(set) var isRinging = false
    /// 0 at the start of the ramp, 1 once fully faded in.
    @Published private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var startDate: Date?

    let rampDuration: TimeInterval

    init(rampDuration: TimeInterval = 90) {
        self.rampDuration = rampDuration
    }

    func start() {
        guard !isRinging else { return }
        isRinging = true
        progress = 0
        originalBrightness = UIScreen.main.brightness
        startDate = Date()

        configureAudioSession()
        loadPlayer()
        player?.volume = 0
        player?.play()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        UIScreen.main.brightness = originalBrightness
        isRinging = false
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func tick() {
        guard let startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        let t = min(1, elapsed / rampDuration)
        progress = t

        // Ease-in: the first moments are barely audible/visible, like first light.
        let eased = t * t

        player?.volume = Float(eased)

        let minBrightness: CGFloat = 0.05
        let targetBrightness = max(originalBrightness, 1.0)
        UIScreen.main.brightness = minBrightness + (targetBrightness - minBrightness) * CGFloat(eased)

        if t >= 1 {
            timer?.invalidate()
            timer = nil
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func loadPlayer() {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "wav") else {
            print("chime.wav not found in app bundle")
            return
        }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.prepareToPlay()
    }
}
