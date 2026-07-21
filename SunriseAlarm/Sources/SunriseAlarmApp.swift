import SwiftUI
import UserNotifications

@main
struct SunriseAlarmApp: App {
    // A plain, app-lifetime-owned instance rather than @StateObject: the App
    // struct itself persists for the whole app run, and `init()` needs a
    // fully-formed class reference to hand to the background task registration
    // below (an @StateObject's wrappedValue can't safely be captured there).
    private let store = AlarmStore()
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = NotificationDelegate()

    init() {
        // Registration must happen before the app finishes launching so the
        // system can hand a background refresh task to us later.
        let store = self.store
        AlarmScheduler.registerBackgroundTask(
            coordinateProvider: { [weak store] in store?.locationManager.coordinate },
            offsetProvider: { [weak store] in store?.offsetMinutes ?? 10 }
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    notificationDelegate.store = store
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.recomputeAndSchedule()
            }
        }
    }
}
