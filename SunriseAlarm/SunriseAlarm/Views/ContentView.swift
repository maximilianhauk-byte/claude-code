import SwiftUI
import CoreLocation
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var settings: AlarmSettings
    @EnvironmentObject private var scheduler: AlarmScheduler
    @ObservedObject private var appState = AppState.shared

    @State private var showRingingView = false
    @State private var ringingRampSeconds: Double = 15
    @State private var notificationAuthDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Standort") {
                    HStack {
                        Image(systemName: locationManager.coordinate == nil ? "location.slash" : "location.fill")
                            .foregroundStyle(locationManager.coordinate == nil ? .red : .green)
                        VStack(alignment: .leading) {
                            if let name = locationManager.placeName {
                                Text(name)
                            } else if locationManager.coordinate != nil {
                                Text("Standort ermittelt")
                            } else {
                                Text("Kein Standort")
                            }
                            Text(authorizationDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if locationManager.authorizationStatus == .notDetermined {
                            Button("Erlauben") { locationManager.requestPermission() }
                        }
                    }
                }

                Section("Wecker") {
                    Toggle("Sonnenaufgangs-Wecker aktiv", isOn: $settings.isEnabled)
                        .onChange(of: settings.isEnabled) { requestNotificationsIfNeeded(); scheduler.recomputeAndReschedule() }

                    Stepper(value: $settings.offsetMinutes, in: 1...60, step: 1) {
                        Text("\(Int(settings.offsetMinutes)) Min vor Sonnenaufgang")
                    }
                    .onChange(of: settings.offsetMinutes) { scheduler.recomputeAndReschedule() }

                    if let sunrise = scheduler.nextSunrise {
                        LabeledContent("Nächster Sonnenaufgang", value: sunrise.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let alarm = scheduler.nextAlarmDate {
                        LabeledContent("Weckt dich um", value: alarm.formatted(date: .abbreviated, time: .shortened))
                    }
                    if notificationAuthDenied {
                        Text("Benachrichtigungen sind deaktiviert. Aktiviere sie in Einstellungen > SunriseAlarm, damit der Wecker auch klingelt, wenn die App nicht offen ist.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vorschau der Ramp-Dauer: \(Int(settings.testRampSeconds)) Sek.")
                        Slider(value: $settings.testRampSeconds, in: 5...60, step: 5)
                    }

                    Button {
                        ringingRampSeconds = settings.testRampSeconds
                        showRingingView = true
                    } label: {
                        Label("Jetzt testen (App offen)", systemImage: "play.fill")
                    }

                    Button {
                        requestNotificationsIfNeeded()
                        scheduler.scheduleDebugNotification(secondsFromNow: 60)
                    } label: {
                        Label("Test-Benachrichtigung in 1 Minute", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Selbst ausprobieren")
                } footer: {
                    Text("Der erste Button zeigt sofort die komplette Weck-Animation (Klingeln + Helligkeit) in der App. Der zweite Button schickt in einer Minute eine echte Benachrichtigung – sperr dein iPhone danach, um den Weck-Ablauf auch im Hintergrund zu testen.")
                }
            }
            .navigationTitle("Sonnenaufgangs-Wecker")
        }
        .fullScreenCover(isPresented: $showRingingView) {
            AlarmRingingView(
                rampSeconds: ringingRampSeconds,
                onStop: { showRingingView = false },
                onSnooze: {
                    showRingingView = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5 * 60) {
                        ringingRampSeconds = 5
                        showRingingView = true
                    }
                }
            )
        }
        .onAppear {
            checkNotificationAuthorization()
            scheduler.recomputeAndReschedule()
        }
        .onChange(of: appState.pendingRingRequest) {
            guard appState.pendingRingRequest else { return }
            appState.pendingRingRequest = false
            ringingRampSeconds = settings.realRampSeconds
            showRingingView = true
        }
    }

    private var authorizationDescription: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "Standortzugriff noch nicht erteilt"
        case .denied, .restricted: return "Standortzugriff verweigert – in Einstellungen aktivieren"
        case .authorizedAlways: return "Standortzugriff: Immer"
        case .authorizedWhenInUse: return "Standortzugriff: Bei App-Nutzung"
        @unknown default: return ""
        }
    }

    private func requestNotificationsIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]) { granted, _ in
            DispatchQueue.main.async { notificationAuthDenied = !granted }
        }
    }

    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthDenied = settings.authorizationStatus == .denied
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(AlarmSettings())
        .environmentObject(AlarmScheduler(settings: AlarmSettings(), locationManager: LocationManager()))
}
