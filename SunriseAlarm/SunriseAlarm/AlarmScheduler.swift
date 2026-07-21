import Foundation
import UIKit
import UserNotifications
import CoreLocation

/// Ties location + sunrise calculation + wake sequence together, and also
/// arms a backup local notification so an audible alert still fires even if
/// the app gets backgrounded or the phone gets locked overnight.
@MainActor
final class AlarmScheduler: ObservableObject {
    @Published var isArmed = false
    @Published var nextSunrise: Date?
    @Published var nextWakeTime: Date?
    @Published var statusMessage: String = ""

    let wakeController = WakeSequenceController()

    var offsetMinutes: Double = 10
    var fadeDurationMinutes: Double = 10

    private var checkTimer: Timer?
    private let notificationIdentifier = "sunrise-alarm-wake"

    func arm(coordinate: CLLocationCoordinate2D) {
        guard let wake = computeNextWakeTime(coordinate: coordinate) else {
            statusMessage = "Sonnenaufgang konnte an diesem Ort nicht berechnet werden."
            return
        }
        beginCountdown(to: wake)
        statusMessage = "Alarm aktiv – Weckzeit \(Self.formatter.string(from: wake))"
    }

    /// Schedules a test alarm `minutesFromNow` in the future through the
    /// exact same code path as the real sunrise alarm (foreground timer +
    /// backup notification), so you can test the full flow end-to-end.
    func armTest(minutesFromNow: Double) {
        let wake = Date().addingTimeInterval(minutesFromNow * 60)
        beginCountdown(to: wake)
        statusMessage = "Testalarm geplant für \(Self.formatter.string(from: wake))"
    }

    func disarm() {
        isArmed = false
        checkTimer?.invalidate()
        checkTimer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        wakeController.stop()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        statusMessage = "Alarm deaktiviert."
    }

    func computeNextWakeTime(coordinate: CLLocationCoordinate2D, from now: Date = Date()) -> Date? {
        for dayOffset in 0..<3 {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: now),
                  let sunrise = SunriseCalculator.sunrise(for: day, latitude: coordinate.latitude, longitude: coordinate.longitude) else {
                continue
            }
            let wake = sunrise.addingTimeInterval(-offsetMinutes * 60)
            if wake > now {
                nextSunrise = sunrise
                nextWakeTime = wake
                return wake
            }
        }
        return nil
    }

    private func beginCountdown(to wake: Date) {
        nextWakeTime = wake
        isArmed = true
        UIApplication.shared.isIdleTimerDisabled = true

        scheduleBackupNotification(at: wake)

        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkTick() }
        }
    }

    private func checkTick() {
        guard let wake = nextWakeTime else { return }
        if Date() >= wake && !wakeController.isRunning {
            wakeController.start(duration: fadeDurationMinutes * 60)
        }
    }

    private func scheduleBackupNotification(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Guten Morgen"
        content.body = "Sanfter Sonnenaufgangs-Alarm"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        UNUserNotificationCenter.current().add(request)
    }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
