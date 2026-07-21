import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var alarmManager: AlarmManager
    @ObservedObject private var settings = SettingsBridge.shared

    @State private var nextSunrise: Date?
    @State private var pendingArm = false

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                alarmSection
                testSection
                aboutSection
            }
            .navigationTitle("Sunrise Alarm")
            .onAppear(perform: refreshSunrise)
            .onChange(of: locationManager.coordinate?.latitude) { _, _ in
                refreshSunrise()
                if pendingArm, let coordinate = locationManager.coordinate {
                    pendingArm = false
                    alarmManager.arm(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
            }
        }
        .fullScreenCover(isPresented: isRinging) {
            RingingView {
                alarmManager.stopRinging()
                alarmManager.disarm()
            }
        }
    }

    private var isRinging: Binding<Bool> {
        Binding(
            get: { alarmManager.phase == .ringing },
            set: { _ in }
        )
    }

    // MARK: - Sections

    private var locationSection: some View {
        Section("Standort") {
            if let coordinate = locationManager.coordinate {
                LabeledContent("Position") {
                    Text(String(format: "%.3f, %.3f", coordinate.latitude, coordinate.longitude))
                }
                if let place = locationManager.placeName {
                    LabeledContent("Ort", value: place)
                }
            } else {
                Text("Standort wird ermittelt…")
                    .foregroundStyle(.secondary)
            }

            if let sunrise = nextSunrise {
                LabeledContent("Nächster Sonnenaufgang") {
                    Text(sunrise.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Button("Standort aktualisieren") {
                locationManager.requestLocation()
                refreshSunrise()
            }
        }
    }

    private var alarmSection: some View {
        Section("Wecker") {
            Toggle("Aktiviert", isOn: Binding(
                get: { if case .armed = alarmManager.phase { return true } else { return false } },
                set: { isOn in toggleAlarm(isOn) }
            ))

            Stepper(value: $settings.offsetMinutes, in: 1...60) {
                LabeledContent("Vorlaufzeit", value: "\(Int(settings.offsetMinutes)) Min. vor Sonnenaufgang")
            }

            Stepper(value: $settings.rampDurationMinutes, in: 1...30) {
                LabeledContent("Einblendzeit", value: "\(Int(settings.rampDurationMinutes)) Min.")
            }

            if case .armed(let target) = alarmManager.phase {
                LabeledContent("Weckt dich um", value: target.formatted(date: .omitted, time: .shortened))
                Text("Lass die App im Hintergrund geöffnet (nicht per Wischen beenden) und das Handy am Strom, damit das sanfte Klingeln zuverlässig startet. Als Absicherung ist zusätzlich eine normale Erinnerung geplant.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var testSection: some View {
        Section("Selbst ausprobieren") {
            Button("Vorschau jetzt starten (20 Sek.)") {
                alarmManager.startPreview(duration: 20)
            }
            Button("Vollständiger Test in Echtzeit (\(Int(settings.rampDurationMinutes)) Min.)") {
                alarmManager.startPreview(duration: settings.rampDurationMinutes * 60)
            }
            Button("Testalarm in 60 Sekunden") {
                alarmManager.startDebugAlarm(secondsFromNow: 60, rampSeconds: 20)
            }
            Text("Der letzte Test simuliert den echten Ablauf inklusive Hintergrund-Mechanismus und Backup-Benachrichtigung. Sperre danach kurz dein Handy, um zu prüfen, ob es zuverlässig weckt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            Text("Die Bildschirm-Aufhellung funktioniert nur, solange die App im Vordergrund bzw. das Handy entsperrt ist - das ist eine Einschränkung von iOS. Der sanfte Ton funktioniert auch bei gesperrtem Bildschirm, solange die App nicht manuell beendet wurde.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func toggleAlarm(_ isOn: Bool) {
        if isOn {
            guard let coordinate = locationManager.coordinate else {
                pendingArm = true
                locationManager.requestLocation()
                return
            }
            alarmManager.arm(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } else {
            alarmManager.disarm()
        }
    }

    private func refreshSunrise() {
        guard let coordinate = locationManager.coordinate else { return }
        nextSunrise = SunCalculator.nextSunrise(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

/// Kleine ObservableObject-Brücke, damit die UI direkt an
/// AlarmSettingsStore (UserDefaults) gebunden werden kann.
final class SettingsBridge: ObservableObject {
    static let shared = SettingsBridge()
    private let store = AlarmSettingsStore.shared

    @Published var offsetMinutes: Double {
        didSet { store.offsetMinutes = offsetMinutes }
    }
    @Published var rampDurationMinutes: Double {
        didSet { store.rampDurationMinutes = rampDurationMinutes }
    }

    private init() {
        offsetMinutes = store.offsetMinutes
        rampDurationMinutes = store.rampDurationMinutes
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(AlarmManager())
}
