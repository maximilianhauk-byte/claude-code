# Sunrise Alarm

Ein iPhone-Wecker, der **10 Minuten vor dem Sonnenaufgang an deinem aktuellen
Standort** zu klingeln beginnt: mit einem sanften Glockenklang, der langsam
lauter wird, während gleichzeitig die Bildschirmhelligkeit langsam
hochfährt — wie ein Lichtwecker.

## Was die App macht

- Ermittelt deinen aktuellen Standort (CoreLocation) und berechnet daraus
  die genaue Sonnenaufgangszeit (eigene Implementierung der
  [NOAA-Sonnenaufgangsformel](https://en.wikipedia.org/wiki/Sunrise_equation),
  auf ca. eine Minute genau).
- Plant automatisch eine Erinnerung 10 Minuten vor Sonnenaufgang.
- Wenn die App im Vordergrund/geöffnet ist, wenn die Weckzeit erreicht wird,
  spielt sie einen sanften Klang, der über ~90 Sekunden von lautlos auf volle
  Lautstärke aufgeblendet wird, während der Bildschirm parallel von dunkel auf
  hell hochfährt.
- Ist das iPhone gesperrt oder die App geschlossen, kommt stattdessen eine
  lokale Benachrichtigung mit demselben Klang zum eingestellten Zeitpunkt an
  (iOS erlaubt es Apps nicht, bei gesperrtem Bildschirm selbstständig die
  Helligkeit zu steuern — das ist eine Systemgrenze, keine Einschränkung der
  App).
- Aktualisiert sich automatisch neu, wenn du an einen anderen Ort reist
  (`startMonitoringSignificantLocationChanges`).

## Projekt öffnen und bauen

Das Projekt liegt als reiner Quellcode + [XcodeGen](https://github.com/yonaskolb/XcodeGen)-Spezifikation vor (kein von Hand gepflegtes `.xcodeproj`, das leicht kaputtgehen kann).

1. Auf dem Mac, falls noch nicht vorhanden:
   ```bash
   brew install xcodegen
   ```
2. Im Ordner `SunriseAlarm/` das Xcode-Projekt generieren:
   ```bash
   cd SunriseAlarm
   xcodegen generate
   open SunriseAlarm.xcodeproj
   ```
3. In Xcode: Projekt auswählen → Tab **Signing & Capabilities** → dein
   Apple-ID-Team unter **Team** auswählen (kostenloser persönlicher Account
   reicht zum Testen auf dem eigenen iPhone). Falls die Bundle-ID
   `com.example.sunrisealarm` schon vergeben ist, änderst du sie einfach in
   `project.yml` (Feld `PRODUCT_BUNDLE_IDENTIFIER`) auf etwas Eindeutiges,
   z. B. `com.<deinname>.sunrisealarm`, und führst `xcodegen generate` erneut
   aus.
4. iPhone per Kabel (oder WLAN-Debugging) anschließen, als Ziel auswählen und
   auf **Run** (▶) drücken. Beim ersten Start auf dem iPhone musst du der App
   unter *Einstellungen → Allgemein → VPN & Geräteverwaltung* einmalig
   vertrauen.

Ohne XcodeGen geht es auch manuell: Neues Xcode-Projekt (App, SwiftUI,
Swift) anlegen, die Dateien aus `Sources/` ins Projekt ziehen, `chime.wav`
aus `Resources/` als Bundle-Ressource hinzufügen und die beiden Info.plist
Einträge (`NSLocationWhenInUseUsageDescription`, `UIBackgroundModes = [audio]`)
selbst ergänzen.

## Auf dem eigenen iPhone ausprobieren

In der App gibt es einen Abschnitt **„Testen“** extra dafür, damit du nicht
bis zum echten Sonnenaufgang warten musst:

- **„Wecker jetzt simulieren“** — startet sofort genau die Sequenz, die 10
  Minuten vor Sonnenaufgang ablaufen würde: sanfter Klang, der lauter wird,
  Bildschirm, der heller wird. So kannst du Lautstärke, Helligkeitsrampe und
  das Aussehen des Weckbildschirms direkt beurteilen. Mit „Beenden“ stoppst
  du wieder.
- **„Testbenachrichtigung in 15 Sekunden senden“** — plant eine echte lokale
  Benachrichtigung mit dem Wecker-Sound. Sperre danach dein iPhone, um zu
  prüfen, wie sich der Wecker anhört/anfühlt, wenn das Handy zugesperrt ist
  (also der realistische nächtliche Fall).

Für einen echten End-to-End-Test kannst du außerdem in den iPhone-Einstellungen
unter *Einstellungen → Allgemein → Datum & Uhrzeit* die Uhrzeit manuell ein
paar Minuten vor die nächste berechnete Weckzeit stellen (in der App unter
„Weckzeit (10 Min. vorher)“ sichtbar), die App im Vordergrund lassen und
abwarten — genau wie am echten Morgen.

## Bekannte Grenzen (bewusste Entscheidungen, keine Bugs)

- Bildschirmhelligkeit lässt sich nur steuern, während die App aktiv im
  Vordergrund läuft — iOS verbietet Apps, das bei gesperrtem Bildschirm zu
  tun. Deshalb der Zwei-Wege-Ansatz (App offen → volle Erfahrung, App
  geschlossen/gesperrt → Benachrichtigung mit Sound).
  Für einen echten "Lichtwecker"-Effekt jede Nacht müsstest du das iPhone
  angeschlossen und mit geöffneter App neben dir liegen lassen.
- Standortberechtigung ist auf „Beim Verwenden der App“ ausgelegt (kein
  „Immer“), damit die Berechtigungsanfrage harmlos bleibt. Die
  Standort-/Sonnenaufgangszeit aktualisiert sich dadurch verlässlich jedes
  Mal, wenn du die App öffnest, bei Ortswechsel im Hintergrund nur, wenn iOS
  die App dafür kurz aufweckt.
