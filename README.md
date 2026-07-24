# Mobile Smarty

Party-Brettspiel für Mobile mit Logik-Minispielen.
Godot 4.7 · GL Compatibility · Landscape 1920×1080 · Android/iOS

Der vollständige Projektplan steht in [PLAN.md](PLAN.md).

---

## Einrichtung

```bash
winget install GodotEngine.GodotEngine
```

Projekt in Godot öffnen (`project.godot`). Beim ersten Start läuft die
Bootstrap-Diagnose (`core/bootstrap.tscn`).

**Voraussetzungen für den Android-Export:** OpenJDK 17, Android SDK,
Debug-Keystore. Siehe `docs/android-export.md`.

---

## Die drei Regeln

Sie klingen pedantisch, aber sie sind die Statik des Projekts. Wer sie
bricht, merkt es nicht sofort — sondern in Monat 6, wenn Online-Partien
unerklärlich auseinanderlaufen.

### 1. Zufall ausschließlich über `SeededRng`

```gdscript
# RICHTIG
var wert := rng.next_int(1, 6)
var optionen := rng.shuffled(antworten)

# FALSCH — bricht die Server-Validierung
var wert := randi() % 6 + 1
antworten.shuffle()
```

Verboten in `minigames/` und `board/`: `randi()`, `randf()`,
`randi_range()`, `Array.shuffle()`, `Array.pick_random()` und jedes
frei erzeugte `RandomNumberGenerator`.

**Warum:** Minispiele werden nicht über das Netz synchronisiert. Server und
alle Clients erzeugen aus demselben Seed dieselbe Aufgabenfolge; übertragen
werden nur Antworten und Zeiten (PLAN.md §2.1). Das spart Monate an
Netcode — funktioniert aber nur bei bitgleichem Zufall auf allen Geräten.

### 2. Minispiele sind isoliert

Ein Minispiel greift **nicht** auf `GameState`, Netzwerk oder Bildschirmgröße
zu. Es bekommt einen Seed, gibt ein `MinigameResult` zurück, sonst nichts.
Nur so bleibt es einzeln startbar, testbar und headless validierbar.

### 3. Zeitbudgets sind Designvorgaben, keine Richtwerte

| Was | Ziel |
|---|---|
| Partie gesamt | 12–18 Minuten |
| Ein Minispiel | 45–75 Sekunden |
| Erklärung eines Minispiels | 1 Satz, ~60 Zeichen |
| Bildrate | 60 FPS auf Mittelklasse-Gerät von ~2022 |

Mobile Sessions brechen ab. Über 20 Minuten Partiedauer verlierst du Spieler
mitten im Spiel — und bei Online-Partien ruiniert jeder Abbrecher die Runde
für drei andere.

---

## Struktur

```
core/         Autoloads, SeededRng, Netzwerk, Speicherstand
board/        Isometrische Karte, Felder, Spielfiguren
minigames/    _base/ (das Interface) + eine Mappe pro Kategorie
ui/           Lobby, HUD, Ergebnisse, Menüs
assets/       art/ audio/ — source/ enthält Quelldateien, nicht exportiert
i18n/         Übersetzungs-CSV
tools/        Asset-Validierung, Build-Skripte
tests/        GUT-Tests, v. a. Determinismus
```

## Ein neues Minispiel anlegen

Vorlage: `minigames/rechnen/zielzahl/zielzahl.gd`

1. Ordner unter `minigames/<kategorie>/<name>/`, darin `<name>.gd` und
   `<name>.tscn` (Root-Node vom Typ `Node`)
2. `extends QuizMinigame`, in `_init()` `id`, `category`, `duration_sec`
   und `tutorial_text` setzen
3. `_make_task(index, task_rng)` implementieren — die einzige Pflichtmethode
4. In `MinigameRegistry.ENTRIES` eintragen. Erst dann taucht das Spiel in
   einer Partie auf; ein halbfertiges Spiel im Ordner bleibt außen vor.

Timer, Punktevergabe, Darstellung, Ergebnismeldung und die spätere
Netzwerkübertragung kommen aus dem Framework.

**Grafische Spiele**: `is_graphical()` auf `true`, `draw_task()` und
`draw_option()` implementieren. Alle Zeichendaten gehören in
`task.draw_data` und müssen in `_make_task` deterministisch entstehen —
in den Zeichenmethoden darf nicht gewürfelt werden, sonst sieht jeder
Frame anders aus.

**Merkaufgaben**: `task.study_seconds` setzen. Die Ansicht zeigt dann
zuerst `study_prompt`, blendet aus und gibt erst danach die Antworten
frei. `in_study_phase` sagt der Zeichenmethode, welche Phase läuft.

### Woran ein Minispiel gemessen wird

`tests/minigames_test.tscn` prüft jedes Spiel der Registry automatisch.
Über die technischen Prüfungen hinaus gelten drei Designregeln, die
teurer sind als sie klingen:

- **Falsche Antworten müssen plausibel sein.** Wer die falschen ohne
  Nachdenken ausschließen kann, spielt Mustererkennung statt der
  Fähigkeit, die das Spiel messen soll.
- **Keine Antwort darf schon in der Aufgabe stehen.** Ein Ablenker, der
  sichtbar Teil der Frage ist, ist ein geschenkter Ausschluss.
- **Die Lösung darf keine Vorzugsposition haben.** Steht sie sortiert
  immer an zweiter Stelle, gewinnt man ohne die Aufgabe zu lesen.

## Tests

```bash
godot --headless --path . --script res://tests/determinism_test.gd
```

```bash
godot --headless --path . res://tests/board_match_test.tscn
```

```bash
godot --headless --path . res://tests/minigames_test.tscn
```

Beide liefern Exit-Code 0 bei Erfolg. Der Partietest spielt drei komplette
Partien ohne Grafik durch und prüft unter anderem, dass zwei Läufe mit
demselben Seed Zug für Zug identisch verlaufen.

Der Partietest läuft als **Szene**, nicht über `--script`: Im Script-Modus
startet Godot ohne Autoloads, `GameState` wäre dann nicht vorhanden.

Visuelle Kontrolle ohne Editor (braucht eine Desktop-Sitzung,
`--headless` rendert nichts):

```bash
godot --path . --resolution 1920x1080 res://tools/screenshot_board.tscn
```

```bash
godot --path . --resolution 1920x1080 res://tools/screenshot_minigames.tscn
```

Logiktests prüfen, ob Aufgaben eindeutig und deterministisch sind. Ob man
sie auch *lesen* kann — Kontrast, Größen, Überlappungen, abgeschnittene
Formen — sieht man nur im Bild. Die Screenshots landen unter
`%APPDATA%\Godot\app_userdata\Mobile Smarty\shots`.

Platzhalter-Grafiken neu erzeugen:

```bash
python tools/gen_placeholder_art.py
```

## Determinismus prüfen

Die Bootstrap-Szene führt bei jedem Start einen Selbsttest aus und zeigt
einen **Fingerprint**. Dieser Wert muss auf jedem Zielgerät identisch sein.
Weicht er zwischen Windows und Android ab, ist der Netcode-Ansatz gebrochen —
das ist ein Blocker, kein Schönheitsfehler.

## Hinweis zu `export_presets.cfg`

Absichtlich in `.gitignore`: enthält Keystore-Pfade und Passwörter.
Vorlage ohne Geheimnisse liegt unter `docs/`.
