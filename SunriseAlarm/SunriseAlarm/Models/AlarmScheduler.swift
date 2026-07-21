import Foundation
import UserNotifications
import BackgroundTasks
import Combine

/// Computes the next "10 minutes before sunrise" moment for the device's current
/// location and keeps a matching local notification scheduled, so there's a backup
/// alert even if the app isn't open in the foreground when the alarm is due.
final class AlarmScheduler: ObservableObject {

    static let shared = AlarmScheduler(settings: AlarmSettings.shared, locationManager: LocationManager.shared)

    static let backgroundTaskIdentifier = "com.sunrisealarm.refresh"
    static let notificationIdentifier = "com.sunrisealarm.wake"
    static let notificationSoundFile = "Chime.wav"

    @Published var nextSunrise: Date?
    @Published var nextAlarmDate: Date?

    private let settings: AlarmSettings
    private let locationManager: LocationManager

    init(settings: AlarmSettings, locationManager: LocationManager) {
        self.settings = settings
        self.locationManager = locationManager
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTaskIdentifier, using: nil) { [weak self] task in
            self?.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6) // check again in ~6h
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleNextBackgroundRefresh()
        recomputeAndReschedule()
        task.setTaskCompleted(success: true)
    }

    /// Recomputes the next sunrise for the last known location and (re)schedules the
    /// backup local notification. Call this on launch, on location updates, and from
    /// the background refresh task.
    func recomputeAndReschedule() {
        guard settings.isEnabled, let coordinate = locationManager.coordinate else {
            nextSunrise = nil
            nextAlarmDate = nil
            cancelScheduledNotification()
            return
        }

        guard let sunrise = SunCalculator.nextSunrise(
            after: Date(),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ) else {
            return
        }

        let alarmDate = sunrise.addingTimeInterval(-settings.offsetMinutes * 60)
        // If the offset already passed for today's sunrise, aim at tomorrow's sunrise instead.
        let effectiveAlarmDate = alarmDate > Date() ? alarmDate : sunrise
        nextSunrise = sunrise
        nextAlarmDate = effectiveAlarmDate

        scheduleNotification(at: effectiveAlarmDate)
        scheduleNextBackgroundRefresh()
    }

    private func scheduleNotification(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Sonnenaufgang naht"
        content.body = "Zeit, langsam aufzuwachen \u{1F305}"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(Self.notificationSoundFile))
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelScheduledNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }

    /// Schedules a one-off real notification `secondsFromNow` in the future, using the
    /// exact same code path as the real alarm. Lets you lock the phone and confirm the
    /// wake notification actually arrives with sound.
    func scheduleDebugNotification(secondsFromNow: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Test-Wecker"
        content.body = "So klingt/kommt dein Sonnenaufgangs-Alarm."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(Self.notificationSoundFile))
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, secondsFromNow), repeats: false)
        let request = UNNotificationRequest(identifier: "com.sunrisealarm.debugtest", content: content, trigger: trigger)
        center.add(request)
    }
}
