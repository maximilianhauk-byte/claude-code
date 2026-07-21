import SwiftUI
import CoreLocation
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: AlarmStore

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                alarmSettingsSection
                testSection
                aboutSection
            }
            .navigationTitle("Sonnenaufgangs-Wecker")
            .onAppear { store.requestPermissions() }
        }
        .fullScreenCover(isPresented: $store.isRinging) {
            AlarmRingingView(rampDuration: Double(store.offsetMinutes) * 60, isTest: false) {
                store.isRinging = false
                store.recomputeAndSchedule()
            }
        }
        .fullScreenCover(isPresented: $store.isTestRinging) {
            AlarmRingingView(rampDuration: testRampDuration, isTest: true) {
                store.isTestRinging = false
            }
        }
    }

    @State private var testRampDuration: TimeInterval = 15

    // MARK: - Sections

    private var statusSection: some View {
        Section("Status") {
            LabeledContent("Standort") {
                Text(locationStatusText)
                    .foregroundStyle(locationStatusColor)
            }
            if store.locationManager.authorizationStatus == .denied {
                Button("In Einstellungen erlauben") { openSettings() }
            }
            LabeledContent("Benachrichtigungen") {
                Text(store.notificationsAuthorized ? "Erlaubt" : "Nicht erlaubt")
                    .foregroundStyle(store.notificationsAuthorized ? .green : .orange)
            }
            if let sunrise = store.nextSunrise, let wake = store.nextWakeTime {
                LabeledContent("Nächster Sonnenaufgang", value: sunrise.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Weckzeit", value: wake.formatted(date: .abbreviated, time: .shortened))
            } else {
                Text("Warte auf Standort, um den Sonnenaufgang zu berechnen …")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var alarmSettingsSection: some View {
        Section("Weckeinstellungen") {
            Toggle("Wecker aktiv", isOn: $store.isAlarmEnabled)
                .onChange(of: store.isAlarmEnabled) { _, _ in store.recomputeAndSchedule() }

            Stepper(value: $store.offsetMinutes, in: 1...60) {
                LabeledContent("Vor Sonnenaufgang", value: "\(store.offsetMinutes) Min.")
            }
            .onChange(of: store.offsetMinutes) { _, _ in store.recomputeAndSchedule() }

            Toggle("Bedside-Modus", isOn: $store.bedsideModeEnabled)
            Text("Im Bedside-Modus bleibt die App geöffnet, während dein Handy lädt – so kann sie den Bildschirm während des gesamten Weckvorgangs live aufhellen. Ist die App geschlossen, weckt dich stattdessen eine Benachrichtigung mit sanftem Klingelton, und das Aufhellen startet, sobald du die App danach öffnest.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var testSection: some View {
        Section("Ausprobieren") {
            Picker("Testdauer", selection: $testRampDuration) {
                Text("Schnell (15 Sek.)").tag(TimeInterval(15))
                Text("Mittel (60 Sek.)").tag(TimeInterval(60))
                Text("Echtzeit (\(store.offsetMinutes) Min.)").tag(TimeInterval(store.offsetMinutes * 60))
            }

            Button {
                store.startTestAlarm()
            } label: {
                Label("Alarm jetzt testen", systemImage: "play.circle.fill")
                    .font(.headline)
            }

            Text("Simuliert den Weckalarm sofort: sanfter Glockenklang und Bildschirm werden über die gewählte Dauer langsam heller — genau wie am echten Morgen, nur schneller.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            Text("Sonnenaufgangszeiten werden lokal auf dem Gerät aus deinem Standort berechnet (NOAA-Sonnenstandsformel) – ohne Internetverbindung oder externe Server.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var locationStatusText: String {
        switch store.locationManager.authorizationStatus {
        case .notDetermined: return "Noch nicht angefragt"
        case .denied, .restricted: return "Nicht erlaubt"
        case .authorizedWhenInUse, .authorizedAlways:
            return store.locationManager.coordinate != nil ? "Gefunden" : "Wird ermittelt …"
        @unknown default: return "Unbekannt"
        }
    }

    private var locationStatusColor: Color {
        switch store.locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return store.locationManager.coordinate != nil ? .green : .orange
        case .denied, .restricted: return .red
        default: return .secondary
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    ContentView().environmentObject(AlarmStore())
}
