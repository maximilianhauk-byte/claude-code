import Foundation
import UserNotifications
import CoreLocation
import BackgroundTasks

/// Computes the next wake-up time (sunrise minus the configured offset) and
/// schedules a local notification for it.
///
/// iOS does not allow a background app to gradually raise screen brightness
/// or continuously ramp audio while the device is locked — that level of
/// control only exists while the app is in the foreground. So the design
/// here is the same one real sunrise-alarm apps use:
///   1. A local notification with a custom sound fires at the scheduled
///      time even if the app isn't running, so you always hear the chime.
///   2. Tapping that notification (or having the app already open, e.g. in
///      "Bedside Mode") opens `AlarmRingingView`, which does the actual
///      gradual brightness + volume ramp.
///   3. Because sunrise shifts by a minute or so every day, the alarm is
///      recomputed and rescheduled each time the app becomes active, and
///      opportunistically via a background refresh task.
enum AlarmScheduler {
    static let notificationIdentifier = "sunrise-alarm"
    static let categoryIdentifier = "SUNRISE_ALARM"
    static let backgroundTaskIdentifier = "com.sunrisealarm.reschedule"

    /// Computes sunrise for "today" if it hasn't happened yet, otherwise for
    /// tomorrow, and returns (sunrise, wakeTime = sunrise - offset).
    static func nextAlarm(
        from now: Date = Date(),
        coordinate: CLLocationCoordinate2D,
        offsetMinutes: Int
    ) -> (sunrise: Date, wakeTime: Date)? {
        let calendar = Calendar.current
        for dayOffset in 0...1 {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let sunrise = SunCalculator.sunrise(
                      on: candidateDay,
                      latitude: coordinate.latitude,
                      longitude: coordinate.longitude
                  )
            else { continue }
            let wakeTime = sunrise.addingTimeInterval(-Double(offsetMinutes) * 60)
            if wakeTime > now {
                return (sunrise, wakeTime)
            }
        }
        return nil
    }

    static func requestNotificationPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        let center = UNUserNotificationCenter.current()
        registerCategory()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    private static func registerCategory() {
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Cancels any pending alarm notification and schedules a new one for
    /// `wakeTime`, with the gentle bell as its sound.
    static func schedule(wakeTime: Date, sunrise: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Guten Morgen ☀️"
        content.body = "Sanfter Weckruf – der Sonnenaufgang ist in \(minutesUntil(sunrise, from: wakeTime)) Minuten."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("GentleBell.wav"))
        content.categoryIdentifier = categoryIdentifier
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: wakeTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    private static func minutesUntil(_ date: Date, from reference: Date) -> Int {
        max(0, Int(date.timeIntervalSince(reference) / 60))
    }

    // MARK: - Background refresh (keeps the alarm accurate day to day)

    static func registerBackgroundTask(coordinateProvider: @escaping () -> CLLocationCoordinate2D?, offsetProvider: @escaping () -> Int) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            handleBackgroundRefresh(task: task as! BGAppRefreshTask, coordinateProvider: coordinateProvider, offsetProvider: offsetProvider)
        }
    }

    static func scheduleBackgroundRefresh(after wakeTime: Date) {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        // Ask for a refresh shortly after the alarm fires, so tomorrow's
        // sunrise gets computed and scheduled even if the app stays closed.
        request.earliestBeginDate = wakeTime.addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleBackgroundRefresh(
        task: BGAppRefreshTask,
        coordinateProvider: () -> CLLocationCoordinate2D?,
        offsetProvider: () -> Int
    ) {
        defer { task.setTaskCompleted(success: true) }
        guard let coordinate = coordinateProvider() else { return }
        guard let next = nextAlarm(coordinate: coordinate, offsetMinutes: offsetProvider()) else { return }
        schedule(wakeTime: next.wakeTime, sunrise: next.sunrise)
        scheduleBackgroundRefresh(after: next.wakeTime)
    }
}
