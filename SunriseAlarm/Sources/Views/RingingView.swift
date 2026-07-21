import SwiftUI

/// Vollbild-Ansicht während der Wecker klingelt (oder ein Test läuft).
/// Der Hintergrund hellt sich synchron zur echten Bildschirmhelligkeit auf,
/// damit der "Sonnenaufgang"-Effekt sichtbar wird.
struct RingingView: View {
    @EnvironmentObject private var alarmManager: AlarmManager
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.orange.opacity(Double(alarmManager.currentBrightness)),
                    Color.yellow.opacity(Double(alarmManager.currentBrightness) * 0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)

                Text("Guten Morgen")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                VStack(spacing: 6) {
                    Text("Lautstärke: \(Int(alarmManager.currentVolume * 100))%")
                    Text("Helligkeit: \(Int(alarmManager.currentBrightness * 100))%")
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))

                Spacer().frame(height: 40)

                Button(action: onDismiss) {
                    Text("Aufwachen")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
            }
        }
        .transition(.opacity)
    }
}
