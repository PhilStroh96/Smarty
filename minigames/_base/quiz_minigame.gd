class_name QuizMinigame
extends MinigameBase

## Basisklasse für Minispiele nach dem Muster "Aufgabe, vier Antworten,
## so viele wie möglich in der Zeit".
##
## Das deckt den Großteil der Kategorien ab (Erkennen, Analysieren, Rechnen,
## Vorstellen). Minispiele mit anderem Rhythmus — etwa Merkaufgaben mit
## Einprägephase — erben direkt von [MinigameBase].
##
## Eine Unterklasse muss nur [method _make_task] implementieren:
##
## [codeblock]
## extends QuizMinigame
##
## func _make_task(index: int, task_rng: SeededRng) -> MinigameTask:
##     var a := task_rng.next_int(2, 9)
##     var b := task_rng.next_int(2, 9)
##     var richtig := a * b
##     var optionen: Array[String] = [str(richtig)]
##     while optionen.size() < 4:
##         var falsch := str(richtig + task_rng.next_int(-9, 9))
##         if not optionen.has(falsch):
##             optionen.append(falsch)
##     task_rng.shuffle(optionen)
##     return MinigameTask.new("%d x %d" % [a, b], optionen,
##         optionen.find(str(richtig)))
## [/codeblock]

signal task_changed(task: MinigameTask, index: int)

## Wie viele Aufgaben vorbereitet werden.
##
## Großzügig bemessen: Das Spiel endet über den Timer, nicht über die
## Aufgabenliste. Wer schnell ist, soll nicht vorzeitig ins Leere laufen.
const TASK_POOL := 40

var tasks: Array[MinigameTask] = []

## True, solange die Einprägephase der aktuellen Aufgabe läuft.
##
## Zeichenmethoden fragen das ab, um während des Einprägens etwas anderes
## darzustellen als bei der Frage danach. Die Ansicht setzt es, nicht das
## Minispiel.
var in_study_phase: bool = false

var _index: int = 0


func _build() -> void:
	tasks.clear()
	_index = 0
	for i in TASK_POOL:
		# Jede Aufgabe bekommt einen eigenen abgeleiteten Generator.
		# Dadurch bleibt Aufgabe 12 dieselbe, auch wenn sich die Erzeugung
		# von Aufgabe 3 später ändert (PLAN.md §2.1).
		tasks.append(_make_task(i, rng.fork(i)))


func _on_start() -> void:
	if not tasks.is_empty():
		task_changed.emit(tasks[0], 0)


## Die aktuell gestellte Aufgabe.
func current_task() -> MinigameTask:
	if _index < 0 or _index >= tasks.size():
		return null
	return tasks[_index]


func current_index() -> int:
	return _index


## Beantwortet die aktuelle Aufgabe und rückt weiter.
func answer(option_index: int) -> bool:
	var task := current_task()
	if task == null or not is_running():
		return false
	# Während des Einprägens darf nicht geantwortet werden — sonst könnte
	# man die Merkphase überspringen und raten.
	if in_study_phase:
		return false

	var correct := task.is_correct(option_index)
	submit(option_index, correct, _index)

	_index += 1
	progress_changed.emit(_index, tasks.size())

	if _index >= tasks.size():
		# Aufgabenvorrat erschöpft — praktisch unerreichbar, aber dann
		# soll das Spiel sauber enden statt ins Leere zu laufen.
		finish()
		return correct

	task_changed.emit(tasks[_index], _index)
	return correct


# ---------------------------------------------------------------------------
# Von der Unterklasse zu implementieren
# ---------------------------------------------------------------------------

## Erzeugt Aufgabe Nummer [param index].
##
## MUSS deterministisch sein und ausschließlich [param task_rng] als
## Zufallsquelle benutzen — niemals [code]randi()[/code] und niemals den
## Eltern-Generator [member rng].
##
## [param index] darf für Schwierigkeitssteigerung im Spielverlauf genutzt
## werden: spätere Aufgaben dürfen schwerer sein.
func _make_task(_index: int, _task_rng: SeededRng) -> MinigameTask:
	push_error("%s implementiert _make_task() nicht" % get_script().resource_path)
	return MinigameTask.new("?", ["?"], 0)


## Zeichnet die Aufgabe, wenn sie grafisch ist. Wird von der Spielszene
## auf einem Control aufgerufen. Textaufgaben brauchen das nicht.
func draw_task(_canvas: Control, _task: MinigameTask) -> void:
	pass


## Zeichnet Antwortfeld [param option] einer grafischen Aufgabe.
func draw_option(_canvas: Control, _task: MinigameTask, _option: int) -> void:
	pass


## True, wenn Aufgabe und Antworten gezeichnet statt beschriftet werden.
func is_graphical() -> bool:
	return false


## Rechnet die Punktzahl aus rohen Antworten nach — die Wertung des Servers.
##
## Der Server vertraut der vom Client gemeldeten Punktzahl nicht (PLAN.md
## §2.1). Er baut aus dem Seed dieselben Aufgaben ([method setup] muss
## vorher gelaufen sein) und prüft jede Antwort selbst. Ein Client kann so
## nur seine Antworten behaupten, niemals sein Ergebnis.
##
## [param submissions]: je Eintrag { "task": int, "answer": int, ... }.
## Reihenfolge wie beim Spielen — die Punkte-Untergrenze bei 0 wirkt
## kumulativ, deshalb muss die Reihenfolge zur Client-Wertung passen.
func authoritative_score(submissions: Array) -> int:
	var score := 0
	var counted := {}
	for s in submissions:
		var idx: int = s.get("task", -1)
		if idx < 0 or idx >= tasks.size():
			# Ungültiger Aufgabenindex: zählt nicht, statt zu crashen.
			continue
		# Jede Aufgabe zählt nur einmal. Ohne diese Sperre könnte ein
		# Client dieselbe richtig beantwortete Aufgabe tausendfach melden
		# und beliebig viele Punkte erzeugen — die Wertung ist durch die
		# Aufgabenzahl gedeckelt (PLAN.md §2.1, Anti-Cheat).
		if counted.has(idx):
			continue
		counted[idx] = true
		var chosen: int = s.get("answer", -1)
		var is_correct := tasks[idx].is_correct(chosen)
		score += CORRECT_POINTS if is_correct else WRONG_POINTS
		score = maxi(0, score)
	return score
