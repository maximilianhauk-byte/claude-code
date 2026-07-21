# Sonnenwecker (Sunrise Alarm)

Eine SwiftUI-App, die anhand deines Standorts den nächsten Sonnenaufgang
berechnet und dich 10 Minuten davor mit einem sanft anschwellenden Ton weckt,
während der Bildschirm gleichzeitig langsam von dunkel auf hell aufhellt.

Alles läuft offline: Der Sonnenaufgang wird direkt auf dem Gerät berechnet
(kein Internet, kein API-Key nötig), und der Weckton wird synthetisch erzeugt
(kein Audio-Asset nötig).

## Wichtige Einschränkung von iOS (bitte vorher lesen)

iOS erlaubt Apps grundsätzlich **nicht**, im Hintergrund/gesperrt beliebigen
Code auszuführen, den Bildschirm einzuschalten oder die Helligkeit zu ändern.
Deshalb funktioniert diese App wie die meisten "Sonnenaufgangs-Wecker" im
App Store:

- **Hauptmodus:** Handy über Nacht angeschlossen laden, App geöffnet lassen,
  Bildschirm bleibt an (die App deaktiviert den Sperrbildschirm-Timer
  automatisch, solange der Alarm scharf ist). Dann funktionieren Ton-Fade-in
  **und** Helligkeits-Rampe wie gewünscht.
- **Absicherung:** Falls das Handy doch gesperrt/die App in den Hintergrund
  geschickt wird, feuert zusätzlich eine lokale Benachrichtigung mit Ton zur
  Weckzeit — kein sanftes Aufhellen, aber du verschläfst nicht.

Das ist eine Grenze des iOS-Systems selbst, keine Einschränkung der App.

## Projekt in Xcode anlegen

1. Xcode öffnen → **File → New → Project → App**.
2. Name: `SunriseAlarm`, Interface: **SwiftUI**, Language: **Swift**.
3. Die von Xcode automatisch erzeugten Dateien `SunriseAlarmApp.swift` und
   `ContentView.swift` durch die Dateien aus diesem Ordner
   (`SunriseAlarm/SunriseAlarm/`) ersetzen.
4. Die restlichen Dateien aus diesem Ordner ins Projekt ziehen (per Drag &
   Drop im Project Navigator, "Copy items if needed" ankreuzen):
   - `LocationManager.swift`
   - `SunriseCalculator.swift`
   - `AlarmScheduler.swift`
   - `WakeSequenceController.swift`

## Info.plist / Target-Einstellungen

Im Xcode-Target unter **Info** (bzw. "Custom iOS Target Properties")
hinzufügen:

| Key | Wert |
|---|---|
| `NSLocationWhenInUseUsageDescription` | z.B. "Wird benötigt, um den Sonnenaufgang an deinem Standort zu berechnen." |
| `UIBackgroundModes` | Array mit Eintrag `audio` (lässt den Ton notfalls kurz weiterlaufen, falls das Handy gesperrt wird) |

Unter **Signing & Capabilities**: dein Apple-Team (kostenlose Apple-ID reicht
für Tests auf dem eigenen Gerät) auswählen, Bundle Identifier ggf. anpassen
(z.B. `com.deinname.sunrisealarm`).

## Auf dem iPhone testen

1. iPhone per Kabel anschließen, in Xcode oben als Ziel-Gerät auswählen.
2. **Run (⌘R)** drücken. Beim ersten Start auf dem iPhone unter
   **Einstellungen → Allgemein → VPN & Geräteverwaltung** dem
   Entwicklerprofil vertrauen.
3. In der App Standortzugriff und Benachrichtigungen erlauben.

### Ohne auf den echten Sonnenaufgang zu warten

Die App hat extra zwei Testfunktionen, damit du sofort etwas siehst/hörst:

- **"Sofort simulieren (30 Sek.)"** — startet die komplette Aufwach-Sequenz
  (Ton-Fade-in + Helligkeits-Rampe) direkt, komprimiert auf 30 Sekunden.
  Perfekt, um Ton und Helligkeit tagsüber zu prüfen.
- **"Testalarm planen"** — plant einen echten Alarm z.B. in 2 Minuten über
  denselben Code-Pfad wie der echte Sonnenaufgangs-Alarm (inkl. Backup-
  Benachrichtigung). Damit kannst du auch das Verhalten beim Sperren des
  Bildschirms realistisch testen.

## Anpassen

- Offset vor Sonnenaufgang (Standard 10 Min.) und Aufhelldauer (Standard 10
  Min.) sind in der App per Stepper einstellbar.
- Der Weckton wird in `WakeSequenceController.makeChimeBuffer` synthetisch
  erzeugt (zwei sanfte Sinustöne mit leichtem Tremolo) — Frequenzen/Klang
  dort direkt anpassbar.
