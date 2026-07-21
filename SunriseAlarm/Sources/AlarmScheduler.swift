import Combine
import Foundation
import UserNotifications

/// Owns "when is the next alarm" (sunrise minus `minutesBeforeSunrise` at the
/// current location) and keeps a local notification scheduled for it as a
/// backup for when the app isn't open. Also polls so the app can trigger the
/// full fade-in experience itself while it's in the foreground.
final class AlarmScheduler: ObservableObject {
    static let notificationIdentifier = "sunrise-alarm"
    static let categoryIdentifier = "SUNRISE_ALARM"

    @Published var isEnabled: Bool = true {
        didSet { isEnabled ? updateSchedule() : cancelNotification() }
    }
    @Published private(set) var nextSunrise: Date?
    @Published private(set) var nextAlarmTime: Date?
    @Published private(set) var statusMessage: String = "Standort wird ermittelt…"
    @Published private(set) var didReachAlarmTime = false

    let minutesBeforeSunrise: Double = 10

    private var lastLatitude: Double?
    private var lastLongitude: Double?
    private var pollTimer: Timer?

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkAlarmTime()
        }
    }

    func recompute(latitude: Double, longitude: Double, referenceDate: Date = Date()) {
        lastLatitude = latitude
        lastLongitude = longitude

        guard let todaySunrise = SunCalculator.sunrise(on: referenceDate, latitude: latitude, longitude: longitude) else {
            statusMessage = "An diesem Ort geht die Sonne heute nicht normal auf (Polartag/-nacht)."
            nextSunrise = nil
            nextAlarmTime = nil
            cancelNotification()
            return
        }

        var sunrise = todaySunrise
        if sunrise.addingTimeInterval(-minutesBeforeSunrise * 60) <= referenceDate {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: referenceDate)!
            sunrise = SunCalculator.sunrise(on: tomorrow, latitude: latitude, longitude: longitude) ?? sunrise
        }

        nextSunrise = sunrise
        nextAlarmTime = sunrise.addingTimeInterval(-minutesBeforeSunrise * 60)
        statusMessage = "Standort erkannt."

        if isEnabled {
            updateSchedule()
        }
    }

    /// Call after the ringing screen has been dismissed, so we stop
    /// re-triggering and schedule the following day's alarm.
    func acknowledgeAlarmFired() {
        didReachAlarmTime = false
        if let lastLatitude, let lastLongitude {
            recompute(latitude: lastLatitude, longitude: lastLongitude, referenceDate: Date().addingTimeInterval(3600))
        }
    }

    func scheduleTestNotification(secondsFromNow: TimeInterval) {
        scheduleNotification(at: Date().addingTimeInterval(secondsFromNow))
    }

    private func checkAlarmTime() {
        guard isEnabled, !didReachAlarmTime, let alarmTime = nextAlarmTime else { return }
        if Date() >= alarmTime {
            didReachAlarmTime = true
        }
    }

    private func updateSchedule() {
        guard let alarmTime = nextAlarmTime else { return }
        scheduleNotification(at: alarmTime)
    }

    private func scheduleNotification(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Sonnenaufgang"
        content.body = "Guten Morgen — die Sonne geht gleich auf."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("chime.wav"))
        content.categoryIdentifier = Self.categoryIdentifier
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }
}
