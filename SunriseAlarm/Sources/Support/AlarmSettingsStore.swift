import Foundation

/// Persistiert die Wecker-Einstellungen zwischen App-Starts.
final class AlarmSettingsStore {
    static let shared = AlarmSettingsStore()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "alarm.isEnabled"
        static let offsetMinutes = "alarm.offsetMinutes"
        static let rampDurationMinutes = "alarm.rampDurationMinutes"
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.isEnabled) }
        set { defaults.set(newValue, forKey: Keys.isEnabled) }
    }

    /// Minuten vor Sonnenaufgang, zu denen der Wecker beginnt (Standard: 10).
    var offsetMinutes: Double {
        get {
            let value = defaults.double(forKey: Keys.offsetMinutes)
            return value == 0 ? 10 : value
        }
        set { defaults.set(newValue, forKey: Keys.offsetMinutes) }
    }

    /// Dauer der Fade-in-Rampe (Lautstärke + Helligkeit) in Minuten.
    var rampDurationMinutes: Double {
        get {
            let value = defaults.double(forKey: Keys.rampDurationMinutes)
            return value == 0 ? 10 : value
        }
        set { defaults.set(newValue, forKey: Keys.rampDurationMinutes) }
    }
}
