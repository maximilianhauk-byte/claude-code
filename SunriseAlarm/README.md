# Sunrise Alarm

Eine kleine SwiftUI-iOS-App, die dich standortabhängig **10 Minuten vor dem
Sonnenaufgang** weckt: mit einem sanften, sich in Lautstärke steigernden
Glockenklang und gleichzeitig langsam heller werdendem Bildschirm.

Der Sonnenaufgang wird komplett offline berechnet (NOAA-Sonnenstand-
Algorithmus, keine externe API), aus dem per CoreLocation ermittelten
Standort.

## Browser-Testversion (kein Mac/Xcode nötig)

Unter `web/index.html` liegt eine eigenständige HTML-Seite, die dieselbe
Sonnenaufgangs-Berechnung, denselben prozedural erzeugten Klingelton und
eine visuelle Aufhell-Simulation im Browser nachbildet – zum sofortigen
Ausprobieren in Safari auf dem iPhone, ganz ohne Installation.

Öffne dazu einfach die Datei `SunriseAlarm/web/index.html` in Safari (lokal
per Airdrop/Dateien-App aufs iPhone übertragen, oder von einem beliebigen
Webserver aus). **Wichtig:** Das ist bewusst nur eine Test-/Vorschauversion.
Da Webseiten in Safari keine Hintergrundprozesse und keine echte
Gerätehelligkeit steuern dürfen, kann sie dich – anders als die native
App – nicht zuverlässig wecken, wenn das Handy gesperrt ist. Die
Einschränkungen sind auch direkt in der Seite unter "Einschränkungen
dieser Browser-Testversion" erklärt.

## Projektstruktur

```
SunriseAlarm/
├── project.yml                  # XcodeGen-Projektdefinition
├── web/
│   └── index.html                # Eigenständige Browser-Testversion (Safari)
└── Sources/
    ├── SunriseAlarmApp.swift    # App-Einstiegspunkt
    ├── Models/
    │   ├── SunCalculator.swift      # Sonnenaufgangs-Berechnung (NOAA-Formeln)
    │   ├── LocationManager.swift    # CoreLocation-Wrapper
    │   ├── ChimeSoundGenerator.swift# Prozedural erzeugter Glockenklang (AVAudioEngine)
    │   ├── BrightnessRamp.swift     # Langsames Hochfahren der Bildschirmhelligkeit
    │   └── AlarmManager.swift       # Ablaufsteuerung, Hintergrund-Mechanismus, Fallback
    ├── Views/
    │   ├── ContentView.swift        # Haupt-UI (Standort, Wecker, Test-Buttons)
    │   └── RingingView.swift        # Vollbild-Ansicht während des Weckens
    └── Support/
        └── AlarmSettingsStore.swift # Einstellungen (UserDefaults)
```

## Voraussetzungen

- Ein **Mac** mit installiertem **Xcode** (kostenlos aus dem App Store)
- Ein iPhone mit Lightning-/USB-C-Kabel (oder WLAN-Debugging)
- Eine kostenlose **Apple-ID** reicht aus, um die App 7 Tage lang auf dein
  eigenes Gerät zu laden (kein bezahltes Entwicklerkonto nötig). Nach 7 Tagen
  musst du sie in Xcode einmal neu bauen/installieren.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) zum Erzeugen der
  `.xcodeproj`-Datei aus `project.yml`:
  ```bash
  brew install xcodegen
  ```

## Projekt öffnen und auf dein iPhone laden

1. Im Terminal in diesen Ordner wechseln und das Xcode-Projekt generieren:
   ```bash
   cd SunriseAlarm
   xcodegen generate
   open SunriseAlarm.xcodeproj
   ```
2. In Xcode: Projekt auswählen → Tab **"Signing & Capabilities"** →
   **"Team"** auf deine Apple-ID setzen (ggf. zuerst unter Xcode →
   Settings → Accounts hinzufügen). Ändere bei Bedarf die
   **Bundle Identifier** (in `project.yml`, Feld
   `PRODUCT_BUNDLE_IDENTIFIER`) auf etwas Eindeutiges, z.B.
   `com.deinname.sunrisealarm`.
3. iPhone per Kabel anschließen, als Build-Ziel oben in Xcode auswählen.
4. Auf **Run (▶)** drücken. Beim ersten Start auf dem iPhone unter
   **Einstellungen → Allgemein → VPN & Geräteverwaltung** dem
   Entwicklerprofil vertrauen.
5. App auf dem iPhone öffnen, Standort- und Benachrichtigungs-Berechtigung
   erlauben.

## Wie du es selbst testen kannst

Damit du nicht bis zum echten Sonnenaufgang warten musst, gibt es im
Abschnitt **"Selbst ausprobieren"** in der App drei Testmodi:

- **Vorschau jetzt starten (20 Sek.)** – spielt sofort die komplette
  Sequenz (leiser Ton → lauter, Bildschirm dunkel → hell) in 20 Sekunden ab,
  damit du schnell einen Eindruck bekommst.
- **Vollständiger Test in Echtzeit** – dieselbe Sequenz, aber in der
  tatsächlich eingestellten Einblendzeit (Standard 10 Minuten), damit du das
  reale Tempo erlebst.
- **Testalarm in 60 Sekunden** – aktiviert den *echten* Mechanismus
  (Hintergrund-Timer + Backup-Benachrichtigung) für einen Zeitpunkt eine
  Minute in der Zukunft. Sperre danach dein iPhone, um zu prüfen, ob dich
  der Wecker auch bei gesperrtem Bildschirm zuverlässig erreicht.

## Wichtige Einschränkungen von iOS (bitte vorher lesen)

Damit du realistische Erwartungen hast:

- **Bildschirm-Aufhellung funktioniert nur im Vordergrund.** iOS erlaubt
  Apps grundsätzlich nicht, die Helligkeit zu ändern oder den Bildschirm
  einzuschalten, während sie im Hintergrund oder das Gerät gesperrt ist.
  Der "wird langsam heller"-Effekt ist daher am besten sichtbar, wenn du
  das Telefon entsperrt und die App offen liegen lässt (z.B. auf dem
  Nachttisch) - genau wie es ein echtes Sonnenaufgangslicht tun würde.
- **Der sanfte Ton funktioniert auch bei gesperrtem Bildschirm**, weil die
  App über den `Background Modes: Audio`-Modus einen fast lautlosen
  Dauerton abspielt, um aktiv zu bleiben (Standardtrick vieler
  Wecker-Apps). Das kostet etwas zusätzlichen Akku über Nacht - am besten
  das Handy ans Ladekabel hängen.
- **Die App darf nicht per Wischen aus der App-Übersicht beendet werden**,
  solange der Wecker aktiv ist - sonst stoppt iOS den Hintergrundprozess.
  Als Absicherung plant die App zusätzlich eine normale lokale
  Benachrichtigung (Ton + Vibration) zur gleichen Zeit, die auch dann noch
  auslöst.
- Für den produktiven Dauereinsatz (App Store) müsste man zusätzlich
  `BGTaskScheduler` und ggf. Hintergrund-Standortaktualisierung einbauen;
  für den privaten Gebrauch auf deinem eigenen Gerät reicht der hier
  eingebaute Mechanismus.

## Anpassen

- Vorlaufzeit vor Sonnenaufgang und Einblendzeit sind direkt in der App
  über Stepper einstellbar (Standard: 10 Minuten / 10 Minuten).
- Der Klingelton wird komplett im Code erzeugt (`ChimeSoundGenerator.swift`)
  - kein Audio-Asset nötig. Klangfarbe/Frequenzen lassen sich dort in
    `partials` anpassen.
