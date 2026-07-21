import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var scheduler = AlarmScheduler()
    @StateObject private var alarmPlayer = AlarmPlayer()

    @State private var showRinging = false
    @State private var testNotificationMessage: String?

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(scheduler.statusMessage)
                        .foregroundStyle(.secondary)
                    if let sunrise = scheduler.nextSunrise {
                        LabeledContent("Sonnenaufgang", value: timeFormatter.string(from: sunrise))
                    }
                    if let alarmTime = scheduler.nextAlarmTime {
                        LabeledContent("Weckzeit (10 Min. vorher)", value: timeFormatter.string(from: alarmTime))
                    }
                    Toggle("Wecker aktiv", isOn: $scheduler.isEnabled)
                } header: {
                    Text("Sonnenaufgangswecker")
                }

                Section {
                    Button("Wecker jetzt simulieren") {
                        showRinging = true
                        alarmPlayer.start()
                    }

                    Button("Testbenachrichtigung in 15 Sekunden senden") {
                        scheduler.scheduleTestNotification(secondsFromNow: 15)
                        testNotificationMessage = "Gesendet — sperre jetzt dein iPhone, um Ton & Benachrichtigung zu testen."
                    }

                    if let message = testNotificationMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Testen")
                } footer: {
                    Text("„Wecker jetzt simulieren“ zeigt sofort das sanfte Klingeln mit langsam heller werdendem Bildschirm — genau wie 10 Minuten vor dem echten Sonnenaufgang. Die Bildschirmhelligkeit kann iOS nur steuern, während die App geöffnet ist; bei gesperrtem iPhone hörst du stattdessen den Wecker-Ton über die Benachrichtigung.")
                }
            }
            .navigationTitle("Sunrise Alarm")
        }
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.requestOneTimeLocation()
            scheduler.startPolling()
        }
        .onChange(of: locationManager.location) { newLocation in
            guard let newLocation else { return }
            scheduler.recompute(
                latitude: newLocation.coordinate.latitude,
                longitude: newLocation.coordinate.longitude
            )
        }
        .onChange(of: scheduler.didReachAlarmTime) { fired in
            guard fired, !alarmPlayer.isRinging else { return }
            showRinging = true
            alarmPlayer.start()
        }
        .fullScreenCover(isPresented: $showRinging) {
            AlarmRingingView(alarmPlayer: alarmPlayer) {
                alarmPlayer.stop()
                showRinging = false
                scheduler.acknowledgeAlarmFired()
            }
        }
    }
}

#Preview {
    ContentView()
}
