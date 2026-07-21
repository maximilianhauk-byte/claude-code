import Foundation
import CoreLocation
import Combine

/// Holds the app's persisted settings and the currently-computed next
/// alarm, and is the single place that (re)schedules the notification
/// whenever something relevant changes (location fix, offset, enabled).
final class AlarmStore: ObservableObject {
    @Published var isAlarmEnabled: Bool {
        didSet { UserDefaults.standard.set(isAlarmEnabled, forKey: Keys.enabled) }
    }
    @Published var offsetMinutes: Int {
        didSet { UserDefaults.standard.set(offsetMinutes, forKey: Keys.offset) }
    }
    @Published var bedsideModeEnabled: Bool {
        didSet { UserDefaults.standard.set(bedsideModeEnabled, forKey: Keys.bedside) }
    }
    @Published var notificationsAuthorized = false
    @Published var nextSunrise: Date?
    @Published var nextWakeTime: Date?
    @Published var isRinging = false
    @Published var isTestRinging = false

    let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let enabled = "sunrise.alarmEnabled"
        static let offset = "sunrise.offsetMinutes"
        static let bedside = "sunrise.bedsideMode"
    }

    init() {
        let defaults = UserDefaults.standard
        isAlarmEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        offsetMinutes = defaults.object(forKey: Keys.offset) as? Int ?? 10
        bedsideModeEnabled = defaults.object(forKey: Keys.bedside) as? Bool ?? false

        locationManager.$coordinate
            .compactMap { $0 }
            .sink { [weak self] _ in self?.recomputeAndSchedule() }
            .store(in: &cancellables)
    }

    func requestPermissions() {
        locationManager.requestPermission()
        AlarmScheduler.requestNotificationPermission { [weak self] granted in
            self?.notificationsAuthorized = granted
        }
    }

    /// Call when location, offset, or enabled state changes, and whenever
    /// the app becomes active (sunrise shifts a little every day).
    func recomputeAndSchedule() {
        guard let coordinate = locationManager.coordinate else {
            locationManager.requestLocation()
            return
        }
        guard let next = AlarmScheduler.nextAlarm(coordinate: coordinate, offsetMinutes: offsetMinutes) else {
            nextSunrise = nil
            nextWakeTime = nil
            return
        }
        nextSunrise = next.sunrise
        nextWakeTime = next.wakeTime

        if isAlarmEnabled {
            AlarmScheduler.schedule(wakeTime: next.wakeTime, sunrise: next.sunrise)
            AlarmScheduler.scheduleBackgroundRefresh(after: next.wakeTime)
        } else {
            AlarmScheduler.cancel()
        }
    }

    func startTestAlarm() {
        isTestRinging = true
    }

    func startRealAlarm() {
        isRinging = true
    }
}
