import UIKit
import UserNotifications
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Must be registered before this method returns, per BGTaskScheduler's contract.
        AlarmScheduler.shared.registerBackgroundTask()
        return true
    }

    /// Shows the alert + plays the chime sound even while the app is in the foreground,
    /// so testing with "Test-Benachrichtigung in 1 Minute" behaves the same as a real wake.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        if id == AlarmScheduler.notificationIdentifier || id == "com.sunrisealarm.debugtest" {
            DispatchQueue.main.async {
                AppState.shared.pendingRingRequest = true
            }
        }
        completionHandler()
    }
}
