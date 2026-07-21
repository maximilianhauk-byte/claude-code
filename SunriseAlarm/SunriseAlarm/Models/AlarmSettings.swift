import Foundation
import Combine

/// User-configurable alarm settings, persisted to UserDefaults.
final class AlarmSettings: ObservableObject {

    static let shared = AlarmSettings()

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    /// How many minutes before sunrise the alarm should start ramping up.
    @Published var offsetMinutes: Double {
        didSet { UserDefaults.standard.set(offsetMinutes, forKey: Keys.offsetMinutes) }
    }

    /// How many seconds the light/sound ramp takes when triggered from the "Jetzt testen"
    /// preview button. Kept short by default so you don't have to wait minutes to see it work.
    @Published var testRampSeconds: Double {
        didSet { UserDefaults.standard.set(testRampSeconds, forKey: Keys.testRampSeconds) }
    }

    private enum Keys {
        static let isEnabled = "alarm.isEnabled"
        static let offsetMinutes = "alarm.offsetMinutes"
        static let testRampSeconds = "alarm.testRampSeconds"
    }

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        offsetMinutes = defaults.object(forKey: Keys.offsetMinutes) as? Double ?? 10
        testRampSeconds = defaults.object(forKey: Keys.testRampSeconds) as? Double ?? 15
    }

    /// The real ramp duration used for the actual alarm: matches the offset, so the
    /// chime/brightness reach full intensity exactly at sunrise.
    var realRampSeconds: Double { offsetMinutes * 60 }
}
