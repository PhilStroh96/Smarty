# Android-Export

Stand: Juli 2026 · Godot 4.7.1-stable

## Eingerichtete Umgebung

| Komponente | Wert |
|---|---|
| Godot | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.1-stable_win64.exe` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` (build-tools 34.0.0 / 35.0.0 / **36.1.0**, platforms/android-35 + android-36, platform-tools, cmdline-tools/latest) |
| JDK | `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot` (OpenJDK 17) |
| Debug-Keystore | `%APPDATA%\Godot\keystores\debug.keystore` (Alias `androiddebugkey`, Passwort `android`) |

Die Pfade stehen in `%APPDATA%\Godot\editor_settings-4.7.tres` unter
`export/android/*`. Wenn der Export mit „Android SDK path is invalid"
abbricht, ist dort der erste Blick.

### build-tools 36.1.0 ist Pflicht

Godot 4.7.1 erwartet laut `android_source.zip/config.gradle` exakt
build-tools **36.1.0**. Fehlt die Version, exportiert Godot trotzdem, fällt
aber still auf 34.0.0 zurück und meldet nur:

```
Could not find version of build tools that matches Target SDK, using 34.0.0
```

Der Debug-Build funktioniert damit, aber der Fallback ist nichts, was man
in einen Release-Build tragen will. Bei einem Godot-Update prüfen, ob sich
die erwartete Version geändert hat.

### SDK-Komponenten nachinstallieren

```bash
"$LOCALAPPDATA/Android/Sdk/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="$LOCALAPPDATA/Android/Sdk" --list
```

`sdkmanager` ist seit cmdline-tools 22.0 als deprecated markiert;
Nachfolger ist das `android`-CLI im selben Verzeichnis. Für unsere Zwecke
funktioniert `sdkmanager` weiterhin.

## Build

```bash
godot --headless --path . --export-debug "Android" build/android/mobile-smarty.apk
```

Release-Build (braucht einen echten Keystore, siehe unten):

```bash
godot --headless --path . --export-release "Android" build/android/mobile-smarty.apk
```

## Auf dem Gerät installieren

```bash
adb install -r build/android/mobile-smarty.apk
```

Ohne USB-Kabel: APK auf das Handy kopieren und im Dateimanager öffnen.
Android verlangt dafür einmalig „Installation aus unbekannten Quellen"
für die jeweilige App.

Live-Log vom Gerät:

```bash
adb logcat -s godot
```

## ⚠️ Vor dem ersten Store-Upload zu klären

### Package-Name ist unveränderlich

Aktuell: `de.mobilesmarty.game` — **vorläufig**.

Nach dem ersten Upload in den Play Store lässt sich der Package-Name nie
wieder ändern. Eine Änderung bedeutet: neue App, neue Store-Seite, null
Bewertungen, keine Update-Verbindung zu bestehenden Installationen.

Der Spielname selbst ist in PLAN.md §8.6 noch offen. Also: **erst den Namen
final entscheiden und markenrechtlich prüfen, dann den Package-Namen setzen,
dann erst hochladen.**

### Release-Keystore

Der Debug-Keystore hat das öffentlich bekannte Standardpasswort `android` —
das ist Konvention und kein Sicherheitsproblem, solange er nur für
Debug-Builds dient.

Für den Release brauchst du einen eigenen Keystore:

```bash
keytool -genkeypair -v -keystore release.keystore -alias mobilesmarty -keyalg RSA -keysize 4096 -validity 10000
```

**Diesen Keystore und sein Passwort niemals verlieren.** Ohne ihn kannst du
keine Updates mehr veröffentlichen — Google Play akzeptiert nur Uploads mit
derselben Signatur. Ein verlorener Keystore bedeutet: neue App-Seite von
null. Mindestens zwei getrennte, verschlüsselte Sicherungen anlegen.

Google Play App Signing nimmt einen Teil dieses Risikos ab (Google verwahrt
den finalen Signaturschlüssel), der Upload-Key bleibt aber deine Verantwortung.

### Weitere Punkte vor Release

- `version/code` bei jedem Store-Upload erhöhen — Play lehnt doppelte ab
- Launcher-Icons setzen (192×192 sowie adaptive Vorder-/Hintergrund 432×432)
- `gradle_build/use_gradle_build=true`, sobald Nakama oder andere Plugins
  dazukommen, die native Bibliotheken mitbringen
- Export-Format auf AAB umstellen (`gradle_build/export_format=1`) —
  Play verlangt App Bundles, keine APKs
- `architectures/armeabi-v7a` aktivieren, falls 32-Bit-Geräte im Zielmarkt
  relevant sind (Reichweite gegen APK-Größe abwägen)

## Hinweis zu `export_presets.cfg`

Die Datei steht in `.gitignore`, weil Godot dort beim Release-Export Pfad und
Passwort des Keystores hineinschreibt. Eine bereinigte Vorlage liegt unter
[export_presets.template.cfg](export_presets.template.cfg) — bei Änderungen
an den Export-Optionen bitte dort nachziehen, damit ein frisch geklontes
Repo weiterhin baubar ist.
