import UIKit
import Combine

/// Erhöht die Bildschirmhelligkeit schrittweise über einen definierten
/// Zeitraum. Funktioniert nur, während die App aktiv/im Vordergrund ist -
/// iOS erlaubt keine Helligkeitsänderung aus dem Hintergrund heraus.
final class BrightnessRamp {
    private var timer: Timer?
    private var originalBrightness: CGFloat?

    /// Fährt die Helligkeit von `startLevel` auf `endLevel` über `duration` Sekunden hoch.
    func start(duration: TimeInterval, startLevel: CGFloat = 0.05, endLevel: CGFloat = 1.0, onTick: ((CGFloat) -> Void)? = nil) {
        stop(restore: false)
        originalBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = startLevel

        let stepInterval = 0.5
        let totalSteps = max(1, Int(duration / stepInterval))
        var currentStep = 0

        timer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = min(1.0, Double(currentStep) / Double(totalSteps))
            let level = startLevel + (endLevel - startLevel) * CGFloat(progress)
            UIScreen.main.brightness = level
            onTick?(level)
            if progress >= 1.0 {
                timer.invalidate()
                self?.timer = nil
            }
        }
    }

    /// Stoppt die Rampe. `restore: true` setzt die ursprüngliche Helligkeit
    /// von vor dem Wecker-Start wieder her (z.B. beim Ausschalten des Alarms).
    func stop(restore: Bool) {
        timer?.invalidate()
        timer = nil
        if restore, let original = originalBrightness {
            UIScreen.main.brightness = original
        }
        originalBrightness = nil
    }
}
