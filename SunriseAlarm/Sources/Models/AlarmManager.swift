import Foundation
import CoreGraphics
import UserNotifications
import Combine

enum AlarmPhase: Equatable {
    case idle
    case armed(target: Date)
    case ringing
}

/// Zentrale Steuerung des Weckers: berechnet den Zieltermin (Sonnenaufgang -
/// X Minuten), hält die App über einen leisen Hintergrund-Ton am Leben, prüft
/// regelmäßig die Zeit und startet dann das sanfte Klingeln + Aufhellen.
///
/// Zusätzlich wird als Absicherung eine lokale Notification zur gleichen Zeit
/// geplant: Falls iOS die App im Hintergrund doch einmal beendet, weckt dich
/// wenigstens Ton + Vibration der Notification.
@MainActor
final class AlarmManager: ObservableObject {
    @Published private(set) var phase: AlarmPhase = .idle
    @Published private(set) var currentVolume: Float = 0
    @Published private(set) var currentBrightness: CGFloat = 0

    private let chime = ChimeSoundGenerator()
    private let brightnessRamp = BrightnessRamp()
    private let settings = AlarmSettingsStore.shared

    private var checkTimer: Timer?
    private var rampTimer: Timer?
    private var target: Date?
    private var rampDuration: TimeInterval = 600

    private static let notificationIdentifier = "sunrise-alarm-fallback"

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Berechnet den nächsten Sonnenaufgang für den Standort und aktiviert den Wecker.
    func arm(latitude: Double, longitude: Double) {
        guard let sunrise = SunCalculator.nextSunrise(latitude: latitude, longitude: longitude) else { return }
        let target = sunrise.addingTimeInterval(-settings.offsetMinutes * 60)
        arm(target: target)
    }

    /// Aktiviert den Wecker direkt für einen festen Zeitpunkt (z.B. für Tests).
    func arm(target: Date) {
        self.target = target
        rampDuration = settings.rampDurationMinutes * 60
        phase = .armed(target: target)
        settings.isEnabled = true

        scheduleFallbackNotification(at: target)
        startKeepAliveAndWatch()
    }

    func disarm() {
        target = nil
        checkTimer?.invalidate()
        checkTimer = nil
        stopRinging()
        chime.stop()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        phase = .idle
        settings.isEnabled = false
    }

    /// Sofortiger Vorschau-Test: spielt die komplette Ramp-Sequenz jetzt ab,
    /// komprimiert auf `duration` Sekunden statt der echten 10 Minuten.
    func startPreview(duration: TimeInterval = 20) {
        rampDuration = duration
        beginRinging()
    }

    /// Testet den kompletten echten Mechanismus (inkl. Hintergrund-Timer und
    /// Fallback-Notification), nur zeitlich verkürzt: Wecker klingelt in
    /// `secondsFromNow` Sekunden. Damit lässt sich z.B. mit gesperrtem Handy
    /// prüfen, ob der Wecker dich wirklich erreicht.
    func startDebugAlarm(secondsFromNow: TimeInterval, rampSeconds: TimeInterval = 30) {
        rampDuration = rampSeconds
        arm(target: Date().addingTimeInterval(secondsFromNow))
    }

    func stopRinging() {
        rampTimer?.invalidate()
        rampTimer = nil
        chime.stop()
        brightnessRamp.stop(restore: true)
        currentVolume = 0
        currentBrightness = 0
        if case .ringing = phase {
            phase = .idle
        }
    }

    // MARK: - Internals

    /// Hält die App über einen fast lautlosen Loop-Sound im Hintergrund am
    /// Leben (Standard-Technik von Wecker-Apps, benötigt "Background Modes:
    /// Audio"), und prüft jede Sekunde, ob der Zielzeitpunkt erreicht ist.
    private func startKeepAliveAndWatch() {
        checkTimer?.invalidate()
        try? chime.start()
        chime.setVolume(0.0001) // praktisch lautlos, hält die Audio-Session aber aktiv

        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let target = self.target else { return }
                if Date() >= target {
                    self.checkTimer?.invalidate()
                    self.checkTimer = nil
                    self.beginRinging()
                }
            }
        }
    }

    private func beginRinging() {
        phase = .ringing
        rampTimer?.invalidate()

        do {
            try chime.start()
        } catch {
            print("Chime start failed: \(error)")
        }

        brightnessRamp.start(duration: rampDuration, startLevel: 0.05, endLevel: 1.0) { [weak self] level in
            self?.currentBrightness = level
        }

        let stepInterval = 0.5
        let totalSteps = max(1, Int(rampDuration / stepInterval))
        var step = 0
        rampTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { return }
                step += 1
                let progress = Float(min(1.0, Double(step) / Double(totalSteps)))
                self.chime.setVolume(progress)
                self.currentVolume = progress
                if progress >= 1.0 {
                    timer.invalidate()
                }
            }
        }
    }

    private func scheduleFallbackNotification(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Sonnenaufgang"
        content.body = "Guten Morgen! Zeit zum Aufwachen."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger)
        center.add(request)
    }
}
