# Sonnenaufgangs-Wecker (SunriseAlarm)

Eine kleine SwiftUI-App für dein iPhone: Sie bestimmt deinen aktuellen Standort,
berechnet daraus offline den nächsten Sonnenaufgang und weckt dich **10 Minuten
davor** mit einem sanften Klingeln, das langsam lauter wird, während der Bildschirm
gleichzeitig langsam heller wird – wie ein Lichtwecker.

## Wie es funktioniert

- **Standort & Sonnenaufgang**: `LocationManager` holt deinen Standort (CoreLocation),
  `SunCalculator` berechnet daraus offline (keine API, kein Internet nötig) die exakte
  Sonnenaufgangszeit für heute/morgen.
- **Wecker-Erlebnis**: 10 Minuten (einstellbar) vor Sonnenaufgang beginnt ein Chime bei
  Lautstärke 0 zu loopen und wird über die eingestellte Zeit hinweg linear lauter, während
  `UIScreen.main.brightness` synchron von fast dunkel auf volle Helligkeit hochfährt.
- **Backup-Benachrichtigung**: Zusätzlich wird eine lokale Notification (mit Sound)
  genau zur Weckzeit geplant, falls die App gerade nicht offen ist.

### Wichtige iOS-Einschränkung, ehrlich gesagt

iOS erlaubt Drittanbieter-Apps **nicht**, im Hintergrund beliebigen Code über Minuten
laufen zu lassen (kein echtes "Wecker klingelt auch bei komplett geschlossener App mit
sanftem Fade"-Verhalten wie bei der eingebauten Uhr-App). Die App ist daher für zwei
Nutzungsarten ausgelegt:

1. **Volles Erlebnis**: Du lässt die App über Nacht offen (Handy am Ladekabel, Bildschirm
   an, wie eine Lichtwecker-Bedside-Einheit). Dann läuft die komplette Ramp-Animation
   (Ton + Helligkeit) exakt wie gewünscht.
2. **Backup**: Ist die App im Hintergrund/geschlossen, bekommst du stattdessen zur
   Weckzeit eine normale, aber zeitkritische (`time-sensitive`) Benachrichtigung mit
   Sound – tippst du sie an, öffnet sich die App direkt im Weck-Bildschirm.

## Selbst testen – ohne auf den echten Sonnenaufgang zu warten

Die App hat dafür extra zwei Buttons im Bereich "Selbst ausprobieren":

1. **"Jetzt testen (App offen)"** – startet sofort die komplette Animation (Klingeln +
   Helligkeit) mit einer kurzen, einstellbaren Dauer (Standard 15 Sek. statt 10 Min.),
   damit du sie in ein paar Sekunden komplett durchlaufen siehst.
2. **"Test-Benachrichtigung in 1 Minute"** – plant eine echte lokale Benachrichtigung in
   60 Sekunden. Sperre danach dein iPhone, um zu prüfen, dass die Benachrichtigung mit
   Sound ankommt und die App beim Antippen direkt im Weck-Bildschirm öffnet.

## Projekt bauen

Du brauchst einen Mac mit Xcode (kostenlos aus dem Mac App Store) sowie dein iPhone
per USB-Kabel oder im selben WLAN.

### Variante A – mit XcodeGen (empfohlen, 2 Minuten)

```bash
brew install xcodegen
cd SunriseAlarm
xcodegen generate
open SunriseAlarm.xcodeproj
```

### Variante B – ohne XcodeGen, manuell in Xcode

1. Xcode öffnen → *File ▸ New ▸ Project* → *iOS ▸ App* → Interface: **SwiftUI**,
   Language: **Swift**, Name z. B. `SunriseAlarm`.
2. Die von Xcode angelegten `ContentView.swift` und `SunriseAlarmApp.swift` löschen.
3. Alle Dateien aus `SunriseAlarm/SunriseAlarm/` (App, Models, Audio, Views, Resources)
   per Drag & Drop ins Xcode-Projekt ziehen ("Copy items if needed" ankreuzen).
4. Im Ziel *Signing & Capabilities*: **Background Modes** hinzufügen und *Location
   updates*, *Audio, AirPlay, and Picture in Picture*, *Background fetch* sowie
   *Background processing* aktivieren.
5. In der Info-Sektion des Targets (oder einer eigenen `Info.plist`) diese Keys ergänzen:
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysAndWhenInUseUsageDescription`
   - `BGTaskSchedulerPermittedIdentifiers` → Array mit dem String `com.sunrisealarm.refresh`

(Variante A erledigt Schritt 4 und 5 automatisch über `project.yml`.)

## Auf dem eigenen iPhone installieren & ausprobieren

1. iPhone per Kabel anschließen (oder WLAN-Debugging in Xcode aktivieren).
2. In Xcode oben dein iPhone als Zielgerät auswählen.
3. Unter *Signing & Capabilities*: bei **Team** deine Apple-ID auswählen (kostenlos –
   Xcode ▸ Settings ▸ Accounts, dort deine Apple-ID hinzufügen, falls noch nicht
   geschehen). Xcode erzeugt dann automatisch ein kostenloses Entwickler-Profil.
4. ▶️ (Run) drücken. Beim ersten Mal meldet das iPhone "Nicht vertrauenswürdiger
   Entwickler" – auf dem iPhone unter *Einstellungen ▸ Allgemein ▸ VPN & Geräteverwaltung*
   deinem Entwicklerprofil vertrauen.
5. Ab iOS 16 muss zusätzlich einmalig der **Entwicklermodus** aktiviert werden:
   *Einstellungen ▸ Datenschutz & Sicherheit ▸ Entwicklermodus* einschalten, iPhone neu
   starten, Aktivierung bestätigen.
6. App auf dem iPhone öffnen, Standortzugriff erlauben, Benachrichtigungen erlauben,
   Wecker aktivieren – und die beiden Test-Buttons ausprobieren wie oben beschrieben.

> Mit einer kostenlosen Apple-ID läuft die installierte App 7 Tage, danach musst du sie
> einfach erneut über Xcode installieren. Für dauerhafte Nutzung ohne Kabel/Xcode wäre
> ein Apple Developer Program-Konto (99 $/Jahr) plus TestFlight nötig.

## Dateien

```
SunriseAlarm/
  project.yml                        XcodeGen-Projektbeschreibung
  SunriseAlarm/
    App/
      SunriseAlarmApp.swift          App-Einstiegspunkt
      AppDelegate.swift              Notification-Handling, Background-Task-Registrierung
      AppState.swift                 Kleiner Zustand für "Notification wurde angetippt"
    Models/
      SunCalculator.swift            Offline-Sonnenaufgangsberechnung
      LocationManager.swift          CoreLocation-Wrapper
      AlarmSettings.swift            Nutzereinstellungen (persistiert)
      AlarmScheduler.swift           Berechnet nächste Weckzeit, plant Notification
    Audio/
      AlarmAudioPlayer.swift         Chime-Loop mit Lautstärke-Fade-in
    Views/
      ContentView.swift              Hauptbildschirm inkl. Test-Buttons
      AlarmRingingView.swift         Weck-Bildschirm (Helligkeit + Ton laufen hoch)
    Resources/
      Chime.wav                      Sanfter, generierter Glocken-Chime
```
