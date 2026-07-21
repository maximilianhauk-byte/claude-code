import SwiftUI

/// Full-screen "the alarm is going off" view. The background color and the
/// text both track `alarmPlayer.progress`, so even the in-app visuals slowly
/// brighten from night-blue to a warm sunrise orange alongside the real
/// screen brightness and the chime volume.
struct AlarmRingingView: View {
    @ObservedObject var alarmPlayer: AlarmPlayer
    var onDismiss: () -> Void

    private var backgroundColor: Color {
        let t = alarmPlayer.progress
        let night = (r: 0.03, g: 0.05, b: 0.15)
        let sunrise = (r: 0.98, g: 0.55, b: 0.20)
        return Color(
            red: night.r + (sunrise.r - night.r) * t,
            green: night.g + (sunrise.g - night.g) * t,
            blue: night.b + (sunrise.b - night.b) * t
        )
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: alarmPlayer.progress)

            VStack(spacing: 24) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .opacity(0.4 + 0.6 * alarmPlayer.progress)

                Text("Guten Morgen")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text(Date(), style: .time)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer().frame(height: 40)

                Button(action: onDismiss) {
                    Text("Beenden")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.25), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
