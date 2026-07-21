import SwiftUI

@main
struct SunriseAlarmApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var alarmManager = AlarmManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(alarmManager)
                .onAppear {
                    alarmManager.requestNotificationPermission()
                    locationManager.requestPermission()
                }
        }
    }
}
