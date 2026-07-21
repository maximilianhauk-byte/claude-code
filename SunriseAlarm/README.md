# Sunrise Alarm

Eine iOS-App, die dich abhängig von deinem aktuellen Standort automatisch
**10 Minuten vor dem Sonnenaufgang** weckt: mit einem sanften Glockenklang,
der über den Weckzeitraum langsam lauter wird, während der Bildschirm
gleichzeitig langsam heller wird.

Die App enthält einen eingebauten **"Alarm jetzt testen"**-Button, mit dem du
den kompletten Weckvorgang sofort auf deinem iPhone ausprobieren kannst, ohne
auf den echten Sonnenaufgang zu warten.

## Wie es funktioniert

- **Sonnenaufgangszeit**: wird komplett lokal auf dem Gerät aus deinem
  GPS-Standort berechnet (`Sources/SunCalculator.swift`, NOAA-Sonnenstands-
  algorithmus). Keine Internetverbindung, kein externer Server nötig.
- **Weckzeitpunkt**: Sonnenaufgang minus dein eingestellter Vorlauf
  (Standard: 10 Minuten), täglich neu berechnet, da sich der Sonnenaufgang
  jeden Tag um ein paar Minuten verschiebt.
- **Sanftes Klingeln**: ein synthetisch erzeugter, weicher Glockenklang
  (`Resources/GentleBell.wav`, erzeugt via `Scripts/generate_gentle_bell.py`
  – keine Lizenzfragen, da selbst generiert).
- **Langsames Aufhellen + Lautstärke-Ramp**: `Sources/AlarmRingingView.swift`
  erhöht `UIScreen.main.brightness` und die Player-Lautstärke über die
  gewählte Dauer mit einer sanften Ease-in-Kurve.

### Eine wichtige iOS-Einschränkung (und wie die App damit umgeht)

Apple erlaubt es Apps **nicht**, im Hintergrund (Bildschirm gesperrt) den
Bildschirm aufzuhellen oder unbegrenzt Ton mit sich ändernder Lautstärke
abzuspielen. Das kann grundsätzlich nur eine App im Vordergrund. Deshalb
funktioniert die App wie andere Sonnenaufgangs-Wecker auch, in zwei Stufen:

1. **App geschlossen / Handy gesperrt**: Zur Weckzeit feuert eine lokale
   Benachrichtigung mit dem sanften Glockenklang als Sound – die hörst du
   auch, wenn die App nicht läuft.
2. **App tippen oder "Bedside-Modus"**: Tippst du die Benachrichtigung an
   (oder lässt die App im Bedside-Modus die Nacht über geöffnet, z. B.
   während das Handy lädt), übernimmt `AlarmRingingView` und lässt Ton +
   Bildschirm über die volle Dauer sanft ansteigen.

Ein `BGAppRefreshTask` (`Sources/AlarmScheduler.swift`) berechnet den
nächsten Sonnenaufgang außerdem opportunistisch neu, wenn iOS der App kurz
Hintergrundzeit gibt, damit der Alarm auch über mehrere Tage ohne
App-Öffnen halbwegs aktuell bleibt. iOS garantiert Background-Refresh-Timing
aber nie exakt – öffne die App daher am besten einmal abends, damit sie den
morgigen Alarm sicher einplant.

## Projektstruktur

```
SunriseAlarm/
├── Sources/
│   ├── SunriseAlarmApp.swift     App-Einstiegspunkt
│   ├── ContentView.swift         Haupt-UI (Status, Einstellungen, Test-Button)
│   ├── AlarmStore.swift          Einstellungen + Planungslogik
│   ├── AlarmScheduler.swift      Berechnet & plant den nächsten Alarm
│   ├── SunCalculator.swift       NOAA-Sonnenaufgangsberechnung
│   ├── LocationManager.swift     CoreLocation-Wrapper
│   ├── AlarmRingingView.swift    Weckbildschirm mit Licht-/Ton-Ramp
│   └── NotificationDelegate.swift
├── Resources/
│   └── GentleBell.wav            Sanfter Glockenklang (generiert)
├── Scripts/
│   └── generate_gentle_bell.py   Regeneriert GentleBell.wav
└── Info.plist                    Referenz für benötigte Info.plist-Keys
```

## Einrichtung in Xcode (auf einem Mac)

Diese Dateien sind reiner Swift/SwiftUI-Quellcode – zum Bauen und auf dein
iPhone zu übertragen brauchst du **Xcode auf einem Mac** (kostenlos im App
Store). Eine kostenlose Apple-ID genügt, um die App für 7 Tage auf dein
eigenes iPhone zu installieren (ohne bezahltes Entwicklerkonto).

1. **Neues Projekt**: Xcode → *File → New → Project → iOS → App*
   - Product Name: `SunriseAlarm`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Use Core Data" / "Include Tests" (nicht nötig)
   - Minimum Deployments: **iOS 17.0** oder neuer (der Code nutzt die
     neuere `onChange(of:) { old, new in }`-Syntax) – in den
     Projekteinstellungen unter *General → Minimum Deployments* prüfen/setzen.

2. **Dateien hinzufügen**: Lösche die von Xcode generierten
   `ContentView.swift` und `SunriseAlarmApp.swift`, ziehe stattdessen alle
   Dateien aus diesem `Sources/`-Ordner sowie `Resources/GentleBell.wav` per
   Drag & Drop ins Projektnavigator-Fenster ("Copy items if needed" ✅,
   Target `SunriseAlarm` ✅).

3. **Info.plist-Einträge**: Wähle das Projekt → Target `SunriseAlarm` →
   Tab *Info* → füge die Keys aus `Info.plist` in diesem Ordner hinzu
   (Standort-Nutzungstext, `UIBackgroundModes`, `BGTaskSchedulerPermittedIdentifiers`).
   Am einfachsten: Rechtsklick auf einen bestehenden Eintrag → *Add Row*,
   oder öffne die Info.plist als Quelltext ("Open As → Source Code") und
   füge die `<key>`/`<value>`-Paare ein.

4. **Capabilities**: Target → Tab *Signing & Capabilities* → *+ Capability*
   → **Background Modes** hinzufügen → Häkchen bei *Background fetch* und
   *Background processing* setzen.

5. **Signing**: Tab *Signing & Capabilities* → wähle dein persönliches
   Apple-ID-Team unter *Team* (falls nicht gelistet: Xcode → Settings →
   Accounts → *+* → deine Apple-ID hinzufügen).

6. **Auf dein iPhone installieren**:
   - iPhone per Kabel (oder über WLAN, wenn eingerichtet) verbinden.
   - Oben in Xcode als Ziel-Gerät dein iPhone auswählen (statt Simulator).
   - ▶️ *Run* drücken.
   - Beim ersten Start auf dem iPhone: *Einstellungen → Allgemein →
     VPN & Geräteverwaltung* öffnen und deinem Entwicklerprofil vertrauen.

## Die App auf deinem iPhone selbst ausprobieren

Nach der Installation:

1. App öffnen, Standort- und Benachrichtigungs-Berechtigung erlauben.
2. Auf der Startseite siehst du direkt den nächsten Sonnenaufgang und die
   berechnete Weckzeit für deinen aktuellen Standort.
3. Unter **"Ausprobieren"** eine Testdauer wählen (z. B. *Schnell, 15 Sek.*)
   und auf **"Alarm jetzt testen"** tippen.
4. Der Bildschirm wechselt sofort in den Weckbildschirm: der Glockenklang
   startet leise und wird lauter, der Bildschirm hellt sich gleichzeitig
   sichtbar auf – genau der Effekt, den du morgens vor Sonnenaufgang
   bekommst, nur komprimiert auf ein paar Sekunden.
5. Mit *Test beenden* springst du zurück; Originalhelligkeit und Ton werden
   zurückgesetzt.
6. Für den echten Alarm: *Wecker aktiv* eingeschaltet lassen und den
   gewünschten Vorlauf (Standard 10 Min.) einstellen. Für die volle
   licht-ansteigende Erfahrung über den kompletten Vorlaufzeitraum die App
   vor dem Einschlafen offen lassen (**Bedside-Modus**); ansonsten weckt dich
   in jedem Fall die Benachrichtigung mit Klingelton.

## Grenzen / Hinweise

- Ich (Claude) konnte dieses Swift/iOS-Projekt in dieser Umgebung **nicht
  kompilieren oder auf einem echten iPhone testen** – hier steht kein
  Xcode/macOS zur Verfügung. Der Code folgt Standard-SwiftUI/CoreLocation/
  AVFoundation-APIs, sollte aber nach dem Einrichten in Xcode einmal
  durchgebaut und geprüft werden; kleinere Anpassungen (z. B. exakte
  Xcode-Version, Signing) können nötig sein.
- Sonnenaufgangsberechnung ist auf ±1 Minute genau (Standardgenauigkeit des
  NOAA-Algorithmus) – für polare Regionen ohne täglichen Sonnenaufgang
  liefert sie bewusst keinen Wert.
- Möchtest du den Glockenklang ändern, ersetze `Resources/GentleBell.wav`
  durch eine eigene Audiodatei (≤ 30 Sek., `.wav`/`.aiff`/`.caf`) mit
  demselben Dateinamen, oder passe `generate_gentle_bell.py` an und führe es
  erneut aus.
