import SwiftUI

@main
struct SunriseAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var settings = AlarmSettings.shared
    @StateObject private var scheduler = AlarmScheduler.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(settings)
                .environmentObject(scheduler)
                .onAppear {
                    locationManager.onLocationUpdate = { [weak scheduler] in
                        scheduler?.recomputeAndReschedule()
                    }
                    if locationManager.authorizationStatus == .authorizedAlways
                        || locationManager.authorizationStatus == .authorizedWhenInUse {
                        locationManager.requestOneTimeLocation()
                        locationManager.startMonitoring()
                    }
                }
        }
    }
}
