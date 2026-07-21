import UserNotifications

/// Lets the wake-up notification show its banner + sound even while the app
/// is already in the foreground, and opens the ramp-up screen when the user
/// taps it.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var store: AlarmStore?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == AlarmScheduler.notificationIdentifier {
            store?.startRealAlarm()
        }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == AlarmScheduler.notificationIdentifier {
            store?.startRealAlarm()
        }
        completionHandler()
    }
}
