import SwiftUI
import UIKit

/// Full-screen "alarm is ringing" experience: chime fades in from silence and the
/// screen fades from dark to full brightness over `rampSeconds`, mimicking a sunrise.
struct AlarmRingingView: View {
    let rampSeconds: Double
    let onStop: () -> Void
    let onSnooze: (() -> Void)?

    @StateObject private var audio = AlarmAudioPlayer()
    @State private var progress: CGFloat = 0
    @State private var brightnessTimer: Timer?
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @State private var previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled

    private var skyColor: Color {
        // Dark blue-violet night sky fading through orange/pink to bright warm daylight.
        let night = (r: 0.03, g: 0.03, b: 0.12)
        let dawn = (r: 1.0, g: 0.55, b: 0.35)
        let day = (r: 1.0, g: 0.96, b: 0.85)

        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

        if progress < 0.5 {
            let t = Double(progress) / 0.5
            return Color(red: lerp(night.r, dawn.r, t), green: lerp(night.g, dawn.g, t), blue: lerp(night.b, dawn.b, t))
        } else {
            let t = (Double(progress) - 0.5) / 0.5
            return Color(red: lerp(dawn.r, day.r, t), green: lerp(dawn.g, day.g, t), blue: lerp(dawn.b, day.b, t))
        }
    }

    var body: some View {
        ZStack {
            skyColor.ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(progress > 0.5 ? .orange : .white)

                Text("Guten Morgen")
                    .font(.largeTitle.bold())
                    .foregroundStyle(progress > 0.5 ? .black : .white)

                Text(Date.now, style: .time)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundStyle(progress > 0.5 ? .black.opacity(0.7) : .white.opacity(0.8))

                Spacer().frame(height: 20)

                if let onSnooze {
                    Button("Schlummern (+5 Min)", action: onSnooze)
                        .buttonStyle(.bordered)
                        .tint(progress > 0.5 ? .black : .white)
                }

                Button("Wecker stoppen", action: stop)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
            }
            .padding()
        }
        .onAppear(perform: start)
        .onDisappear(perform: cleanUp)
    }

    private func start() {
        previousBrightness = UIScreen.main.brightness
        previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true

        audio.start(rampSeconds: rampSeconds)

        let steps = 200
        let stepDuration = max(rampSeconds, 0.1) / Double(steps)
        var currentStep = 0
        // Start a touch above pitch black so the phone isn't literally unreadable at minute zero.
        let startBrightness: CGFloat = 0.05
        UIScreen.main.brightness = startBrightness

        brightnessTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let t = CGFloat(currentStep) / CGFloat(steps)
            progress = t
            UIScreen.main.brightness = startBrightness + (1.0 - startBrightness) * t
            if currentStep >= steps {
                timer.invalidate()
            }
        }
    }

    private func stop() {
        cleanUp()
        onStop()
    }

    private func cleanUp() {
        brightnessTimer?.invalidate()
        brightnessTimer = nil
        audio.stop()
        UIScreen.main.brightness = previousBrightness
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
    }
}

#Preview {
    AlarmRingingView(rampSeconds: 15, onStop: {}, onSnooze: {})
}
