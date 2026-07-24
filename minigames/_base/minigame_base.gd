class_name MinigameBase
extends Node

## Basisklasse für alle Minispiele — der wichtigste Vertrag im Projekt.
##
## Wenn dieses Interface stimmt, kostet Minispiel Nr. 20 einen Bruchteil
## von Nr. 1. Wenn nicht, wird jedes Minispiel ein Sonderfall und das
## Projekt erstickt an seinem eigenen Content (PLAN.md §2.4).
##
## [b]Drei harte Regeln:[/b]
## [br]1. Kein Zugriff auf [code]GameState[/code], Netzwerk oder
##    Bildschirmgröße. Ein Minispiel bekommt einen Seed, gibt ein Ergebnis
##    zurück, sonst nichts. Nur so ist es einzeln startbar, testbar und
##    headless validierbar.
## [br]2. Zufall ausschließlich über [member rng]. Niemals [code]randi()[/code].
## [br]3. Der Aufbau in [method _build] muss deterministisch sein: gleicher
##    Seed und gleiche Schwierigkeit -> exakt gleiche Aufgabenfolge, auf
##    jeder Plattform.
##
## Ableiten so:
## [codeblock]
## extends MinigameBase
##
## func _build() -> void:
##     for i in 10:
##         _tasks.append(rng.fork(i).next_int(1, 99))
##
## func _on_answer(value: int) -> void:
##     submit(value, value == _tasks[_index])
## [/codeblock]

## Die fünf Fähigkeitskategorien (PLAN.md §1.3). Der Rundenmanager zieht
## abwechselnd aus verschiedenen Kategorien, damit keine Spielergruppe
## strukturell benachteiligt wird.
enum Category {
	ERKENNEN,     ## Schnelle visuelle Unterscheidung
	MERKEN,       ## Kurzzeitgedächtnis
	ANALYSIEREN,  ## Logik, Muster, Schlussfolgern
	RECHNEN,      ## Kopfrechnen
	VORSTELLEN,   ## Räumliches Denken
}

## Wird ausgelöst, sobald das Minispiel beendet ist — durch Zeitablauf
## oder weil alle Aufgaben gelöst sind.
signal finished(result: MinigameResult)

## Fortschritt für die Gegneranzeige. Sparsam senden (2–4×/Sekunde).
signal progress_changed(done: int, total: int)

# --- Metadaten (im Editor gesetzt) ---

## Eindeutige Kennung, z. B. [code]&"rechnen_zielzahl"[/code].
@export var id: StringName

@export var category: Category = Category.ERKENNEN

## Spieldauer in Sekunden. Zielkorridor 45–75 (PLAN.md §1.3).
@export_range(15.0, 120.0, 1.0) var duration_sec: float = 60.0

## Die Erklärung. EIN Satz, maximal ~60 Zeichen — bei 4 Spielern online
## gibt es keine Chance auf lange Tutorials.
@export var tutorial_text: String = ""

## Kurze Schleifenanimation, die die Regel zeigt statt sie zu erklären.
@export var tutorial_anim: PackedScene

# --- Laufzeit ---

## Die Zufallsquelle dieses Minispiels. Von [method setup] gesetzt.
var rng: SeededRng

## 0.0 = leichtest, 1.0 = schwerst. Für Solo-Modi und Aufholmechanik.
var difficulty: float = 0.5

var _result: MinigameResult
var _elapsed: float = 0.0
var _running: bool = false


# ---------------------------------------------------------------------------
# Lifecycle — vom Rundenmanager aufgerufen, nicht überschreiben
# ---------------------------------------------------------------------------

## Baut das Minispiel deterministisch auf. Läuft auf allen Clients
## und im Server-Validator mit demselben [param seed].
func setup(seed: int, p_difficulty: float = 0.5) -> void:
	rng = SeededRng.new(seed)
	difficulty = p_difficulty
	_result = MinigameResult.new()
	_elapsed = 0.0
	_running = false
	_build()


## Startet die Uhr. Erst nach dem Tutorial-Countdown aufrufen.
func start() -> void:
	_running = true
	_on_start()


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_on_tick(delta)
	if _elapsed >= duration_sec:
		finish()


## Beendet das Minispiel und meldet das Ergebnis.
func finish() -> void:
	if not _running:
		return
	_running = false
	_on_finish()
	finished.emit(_result)


## Das Ergebnis. Erst nach [signal finished] endgültig.
func get_result() -> MinigameResult:
	return _result


## Läuft die Uhr gerade? Zwischen [method start] und [method finish] true.
##
## Jede Eingabeverarbeitung muss das prüfen — sonst zählen Antworten, die
## nach dem Ablauf des Timers eintreffen, und die Server-Validierung
## verwirft die Ergebnismeldung als unplausibel.
func is_running() -> bool:
	return _running


## Verstrichene Spielzeit in Sekunden.
func elapsed() -> float:
	return _elapsed


## Verbleibende Zeit in Sekunden.
func time_left() -> float:
	return maxf(0.0, duration_sec - _elapsed)


# ---------------------------------------------------------------------------
# Für abgeleitete Minispiele
# ---------------------------------------------------------------------------

## Trägt eine Antwort ein. Von der Minispiel-Logik aufzurufen.
func submit(answer: int, is_correct: bool, task_index: int = -1) -> void:
	if not _running:
		return
	var idx := task_index if task_index >= 0 else _result.submissions.size()
	_result.add_submission(idx, answer, int(_elapsed * 1000.0), is_correct)
	_score_submission(is_correct)


## Standard-Punkteformel: richtig gibt Punkte, falsch kostet weniger als
## richtig einbringt — Raten soll sich nicht lohnen, aber auch nicht
## bestrafend wirken. Überschreibbar, wenn ein Minispiel es braucht.
func _score_submission(is_correct: bool) -> void:
	_result.score += 100 if is_correct else -25
	_result.score = maxi(0, _result.score)


# ---------------------------------------------------------------------------
# Virtuelle Methoden — hier setzt ein konkretes Minispiel an
# ---------------------------------------------------------------------------

## Deterministischer Aufbau. Aufgaben hier erzeugen, ausschließlich
## über [member rng]. Läuft auch headless im Server-Validator.
func _build() -> void:
	pass


## Wird beim Start der Uhr aufgerufen.
func _on_start() -> void:
	pass


## Pro Frame, solange das Minispiel läuft.
func _on_tick(_delta: float) -> void:
	pass


## Aufräumen, letzte Punkte vergeben.
func _on_finish() -> void:
	pass


## Server-seitige Prüfung — läuft headless im Nakama-Match-Handler.
##
## Erwartet wird eine Plausibilitätsprüfung, keine Neuberechnung des
## Spiels: Sind die Aufgabenindizes gültig? Liegt keine Antwort unter der
## menschlichen Reaktionszeit (~150 ms)? Kam nichts nach Ablauf des Timers?
##
## Konkrete Minispiele überschreiben das, wenn ihre Aufgaben mehr Prüfung
## erlauben (z. B. Nachrechnen der korrekten Antwort aus dem Seed).
static func validate(_seed: int, submissions: Array, max_duration_ms: int) -> bool:
	const MIN_HUMAN_REACTION_MS := 150
	var last_time := -1
	for s in submissions:
		var t: int = s.get("time_ms", -1)
		if t < MIN_HUMAN_REACTION_MS or t > max_duration_ms:
			return false
		# Antwortzeiten sind kumulativ und müssen monoton steigen.
		if t <= last_time:
			return false
		last_time = t
	return true
