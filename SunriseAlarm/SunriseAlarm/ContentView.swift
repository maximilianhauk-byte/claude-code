import SwiftUI
import CoreLocation
import UserNotifications

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var scheduler = AlarmScheduler()

    @AppStorage("offsetMinutes") private var offsetMinutes: Double = 10
    @AppStorage("fadeDurationMinutes") private var fadeDurationMinutes: Double = 10
    @State private var testMinutes: Double = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Standort") {
                    switch locationManager.authorizationStatus {
                    case .notDetermined:
                        Button("Standortzugriff erlauben") {
                            locationManager.requestPermission()
                        }
                    case .denied, .restricted:
                        Text("Standortzugriff verweigert. Bitte in den Einstellungen aktivieren.")
                            .foregroundStyle(.red)
                    default:
                        if let coordinate = locationManager.coordinate {
                            Text("Position: \(coordinate.latitude, specifier: "%.3f"), \(coordinate.longitude, specifier: "%.3f")")
                        } else {
                            Text("Position wird ermittelt…")
                        }
                    }
                }

                Section("Einstellungen") {
                    Stepper("Weckzeit: \(Int(offsetMinutes)) Min. vor Sonnenaufgang", value: $offsetMinutes, in: 1...60)
                    Stepper("Aufhelldauer: \(Int(fadeDurationMinutes)) Min.", value: $fadeDurationMinutes, in: 1...30)
                }

                Section("Sonnenalarm") {
                    if let sunrise = scheduler.nextSunrise {
                        LabeledContent("Nächster Sonnenaufgang", value: Self.timeFormatter.string(from: sunrise))
                    }
                    if let wake = scheduler.nextWakeTime {
                        LabeledContent("Weckzeit", value: Self.timeFormatter.string(from: wake))
                    }

                    if scheduler.isArmed {
                        Button("Alarm deaktivieren", role: .destructive) {
                            scheduler.disarm()
                        }
                    } else {
                        Button("Alarm aktivieren") {
                            scheduler.offsetMinutes = offsetMinutes
                            scheduler.fadeDurationMinutes = fadeDurationMinutes
                            if let coordinate = locationManager.coordinate {
                                scheduler.arm(coordinate: coordinate)
                            }
                        }
                        .disabled(locationManager.coordinate == nil)
                    }

                    if !scheduler.statusMessage.isEmpty {
                        Text(scheduler.statusMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Jetzt ausprobieren") {
                    Button("Sofort simulieren (30 Sek.)") {
                        scheduler.wakeController.start(duration: 30)
                    }
                    .disabled(scheduler.wakeController.isRunning)

                    if scheduler.wakeController.isRunning {
                        ProgressView(value: scheduler.wakeController.progress)
                        Button("Simulation stoppen", role: .destructive) {
                            scheduler.wakeController.stop()
                        }
                    }

                    VStack(alignment: .leading) {
                        Stepper("Testalarm in \(Int(testMinutes)) Min.", value: $testMinutes, in: 1...15)
                        Button("Testalarm planen (voller Ablauf inkl. Benachrichtigung)") {
                            scheduler.fadeDurationMinutes = fadeDurationMinutes
                            scheduler.armTest(minutesFromNow: testMinutes)
                        }
                    }
                }
            }
            .navigationTitle("Sonnenwecker")
            .onAppear {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                    locationManager.requestLocation()
                }
            }
            .onChange(of: locationManager.coordinate?.latitude) { _, _ in
                if let coordinate = locationManager.coordinate {
                    scheduler.offsetMinutes = offsetMinutes
                    _ = scheduler.computeNextWakeTime(coordinate: coordinate)
                }
            }
        }
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}

#Preview {
    ContentView()
}
