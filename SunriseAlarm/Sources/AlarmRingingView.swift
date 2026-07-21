import SwiftUI
import AVFoundation
import UIKit
import Combine

/// Drives the actual wake-up experience: gradually raises screen brightness
/// and chime volume from near-zero up to full over `rampDuration`, while the
/// app is in the foreground (the only time iOS allows either of those to be
/// controlled). This is what plays when the user taps the wake-up
/// notification, or immediately when they hit "Test Alarm Now".
final class RingingController: ObservableObject {
    @Published private(set) var progress: Double = 0 // 0...1 over the ramp

    private var player: AVAudioPlayer?
    private var displayTimer: Timer?
    private var startDate: Date?
    private var rampDuration: TimeInterval = 60
    private var originalIdleTimerDisabled = false

    private let minBrightness: CGFloat = 0.04
    private let minVolume: Float = 0.05

    // Screen brightness is intentionally left at its ramped-up level after
    // `stop()` rather than restored — by the time the alarm is dismissed the
    // user is meant to be awake, so snapping back to a dim screen would be
    // counterproductive.
    func start(rampDuration: TimeInterval) {
        self.rampDuration = max(3, rampDuration)
        originalIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true

        configureAudioSession()
        playChime()

        UIScreen.main.brightness = minBrightness
        startDate = Date()
        progress = 0

        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        displayTimer?.invalidate()
        displayTimer = nil
        player?.stop()
        player = nil
        UIApplication.shared.isIdleTimerDisabled = originalIdleTimerDisabled
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func playChime() {
        guard let url = Bundle.main.url(forResource: "GentleBell", withExtension: "wav") else { return }
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = minVolume
            audioPlayer.play()
            player = audioPlayer
        } catch {
            player = nil
        }
    }

    private func tick() {
        guard let startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        let fraction = min(1.0, elapsed / rampDuration)
        // Ease-in curve: starts very gentle, builds toward the end.
        let eased = fraction * fraction
        progress = fraction

        UIScreen.main.brightness = minBrightness + (1.0 - minBrightness) * CGFloat(eased)
        player?.volume = minVolume + (1.0 - minVolume) * Float(eased)

        if fraction >= 1.0 {
            displayTimer?.invalidate()
            displayTimer = nil
        }
    }
}

struct AlarmRingingView: View {
    let rampDuration: TimeInterval
    let isTest: Bool
    let onDismiss: () -> Void

    @StateObject private var controller = RingingController()
    @State private var now = Date()

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text(isTest ? "Testalarm" : "Guten Morgen")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))

                Text(now, style: .time)
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                Button(action: {
                    controller.stop()
                    onDismiss()
                }) {
                    Text(isTest ? "Test beenden" : "Aufstehen")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.18), in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear { controller.start(rampDuration: rampDuration) }
        .onDisappear { controller.stop() }
        .onReceive(clock) { now = $0 }
        .statusBarHidden()
    }

    private var statusText: String {
        let percent = Int(controller.progress * 100)
        return "Weckt dich sanft auf … \(percent)%"
    }

    private var backgroundGradient: LinearGradient {
        let p = controller.progress
        let night = Color(red: 0.03, green: 0.05, blue: 0.14)
        let dawn = Color(red: 0.86, green: 0.47, blue: 0.24)
        let day = Color(red: 1.0, green: 0.82, blue: 0.55)

        let top = interpolate(from: night, to: dawn, fraction: min(1, p * 1.4))
        let bottom = interpolate(from: dawn, to: day, fraction: p)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private func interpolate(from: Color, to: Color, fraction: Double) -> Color {
        let f = max(0, min(1, fraction))
        let fromC = UIColor(from)
        let toC = UIColor(to)
        var (fr, fg, fb, fa): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (tr, tg, tb, ta): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        fromC.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        toC.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        return Color(
            red: Double(fr + (tr - fr) * CGFloat(f)),
            green: Double(fg + (tg - fg) * CGFloat(f)),
            blue: Double(fb + (tb - fb) * CGFloat(f))
        )
    }
}
