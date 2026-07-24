extends QuizMinigame

## Mehr davon: Vier Punktfelder, welches enthält die meisten Punkte?
##
## Trainiert die Mengenabschätzung ("Subitizing" jenseits von vier Objekten).
## Damit das Spiel wirklich Schätzen misst und nicht Abzählen, liegen die
## Felder dicht beieinander — aber nur so dicht, dass der Vorsprung des
## Siegers noch zu sehen ist. Das Maß dafür ist [b]relativ[/b], nicht
## absolut: siehe [constant GAP_EASY]. Bei großem Abstand sähe man die
## Antwort sofort, bei zu kleinem wäre sie nicht mehr wahrnehmbar — beides
## ist hier ausgeschlossen.
##
## [b]Grafisches Minispiel:[/b] Die Antwortfelder werden gezeichnet, nicht
## beschriftet. Sämtliche Zeichendaten entstehen deterministisch in
## [method _make_task] und liegen in [member MinigameTask.draw_data]; in den
## Zeichenmethoden wird nicht gewürfelt, sonst flackerten die Punkte bei
## jedem Frame an eine neue Stelle.

const OPTION_COUNT := 4

## Punkte je Feld — untere und obere Schranke über alle Schwierigkeitsgrade.
## Die obere Schranke ist auch die Obergrenze für das Raster weiter unten.
const MIN_DOTS := 6
const MAX_DOTS := 26

## Geforderter Vorsprung des Siegers, als Anteil seiner eigenen Punktzahl:
## am Anfang der Partie [constant GAP_EASY], am Ende [constant GAP_HARD].
##
## Der Vorsprung ist bewusst ein Anteil und keine feste Punktzahl. Mengen
## werden relativ verglichen, nicht absolut (Webersches Gesetz): 6 gegen 8
## Punkte sieht man sofort, 24 gegen 26 sieht niemand — obwohl der Abstand
## beide Male zwei beträgt. Die Unterscheidungsschwelle liegt bei rund
## 15 Prozent. Ein fester Abstand von ein bis drei Punkten wäre bei 25
## Punkten ein Unterschied von vier Prozent, also weit darunter: Die Aufgabe
## wäre nur noch durch Abzählen lösbar — vier Felder mit je 25 Punkten in
## wenigen Sekunden schafft niemand — und liefe damit auf Raten mit
## 25 Prozent Trefferquote hinaus. [constant GAP_HARD] hält auch die
## schwerste Aufgabe über der Schwelle.
const GAP_EASY := 0.45
const GAP_HARD := 0.20

# --- Raster für die Punktverteilung ---
#
# Die Punkte werden nicht frei gewürfelt, sondern auf verschiedene Zellen
# eines unsichtbaren Rasters verteilt und innerhalb ihrer Zelle zufällig
# versetzt. Das ist der einzige Weg, Überlappungsfreiheit zu [i]garantieren[/i]:
# Ein Punkt bleibt vollständig in seiner Zelle, zwei Punkte in verschiedenen
# Zellen können sich also höchstens berühren. Freies Würfeln mit Nachziehen
# könnte bei 26 Punkten dagegen scheitern oder unterschiedlich lange laufen —
# und wäre damit nicht mehr deterministisch kalkulierbar.
const COLS := 10
const ROWS := 5
const CELLS := COLS * ROWS

## Punktradius als Anteil der kleineren Zellenseite. Kleiner als 0.5, damit
## noch Platz zum Versetzen innerhalb der Zelle bleibt.
const DOT_FILL := 0.36

const PANEL := Color("#14142a")
const PANEL_BORDER := Color("#3a3a5c")

## Alle Punkte haben dieselbe Farbe und dieselbe Größe. Das ist Absicht:
## Sobald Farbe oder Fläche variieren, entscheidet nicht mehr die Anzahl.
## Nebeneffekt: Ohne Farbcodierung gibt es auch kein Rot-Grün-Problem.
const DOT := Color("#ffd369")

## Rahmen um das vollere Beispielfeld im Regelbild.
const ACCENT_BORDER := Color("#ffd369")

const HINT := Color("#9a9ac0")


func _init() -> void:
	id = &"erkennen_mehr"
	category = Category.ERKENNEN
	duration_sec = 50.0
	tutorial_text = "Tippe das Feld mit den meisten Punkten an — schätzen, nicht zählen."


func _make_task(index: int, task_rng: SeededRng) -> MinigameTask:
	var counts := _build_counts(index, task_rng)

	# Der Sieger ist die eindeutige Höchstzahl, deshalb findet find() genau
	# ein Feld. _build_counts stellt die Eindeutigkeit sicher.
	var winner: int = counts.max()
	var correct := counts.find(winner)

	var fields: Array = []
	for i in OPTION_COUNT:
		fields.append(_scatter(counts[i], task_rng))

	var no_labels: Array[String] = []
	var task := MinigameTask.new(_signature(counts), no_labels, correct)
	# Die Antworten werden gezeichnet, es gibt also keine options-Texte.
	task.option_count = OPTION_COUNT
	task.draw_data = {
		"cols": COLS,
		"rows": ROWS,
		"counts": counts,
		"fields": fields,
	}
	return task


## Fortschritt der Partie als Wert von 0 (leichteste Aufgabe) bis 1
## (schwerste). Beides fließt ein: die laufende Nummer der Aufgabe und die
## eingestellte Schwierigkeit.
##
## Bewusst über den gesamten Aufgabenvorrat gestreckt und nicht nach ein
## paar Aufgaben am Anschlag. Eine Kennlinie, die schon bei Aufgabe 10 ihren
## Endwert erreicht, lässt den ganzen Rest der Partie auf einem Niveau
## stehen — und genau diese späten Aufgaben spielt, wer schnell ist.
func _progress(index: int) -> float:
	var lauf := float(index) / float(maxi(TASK_POOL - 1, 1))
	return clampf(lauf * 0.65 + difficulty * 0.35, 0.0, 1.0)


## Grundniveau: so viele Punkte hat der Zweitplatzierte mindestens.
## Mehr Punkte je Feld = weniger Überblick.
##
## Wächst gleichmäßig mit dem Fortschritt statt in wenigen Sprüngen. Eine
## grobe Treppe steht zwischen zwei Stufen über ein Dutzend Aufgaben still,
## und in dieser Zeit merkt niemand, dass es überhaupt weitergeht.
func _base_dots(index: int) -> int:
	return MIN_DOTS + int(_progress(index) * 12.0)


## Die vier Punktzahlen, bereits in Feldreihenfolge gemischt.
##
## Aufbau: ein Grundniveau (der Zweitplatzierte), darüber der Sieger mit dem
## geforderten relativen Vorsprung, darunter zwei Mitläufer knapp unter dem
## Zweiten. Alles liegt eng genug beieinander, dass kein Feld ohne Hinsehen
## ausgeschlossen werden kann — und weit genug, dass der Sieger sichtbar ist.
func _build_counts(index: int, r: SeededRng) -> Array[int]:
	var lo := _base_dots(index)
	var second := r.next_int(lo, lo + 2)

	# Der Vorsprung wächst mit dem Niveau mit, sonst verschwindet er darin.
	# Aufgerundet und nie unter zwei, damit er bei kleinen Mengen nicht auf
	# einen einzelnen Punkt zusammenfällt.
	var rel := lerpf(GAP_EASY, GAP_HARD, _progress(index))
	var lead := maxi(2, ceili(float(second) * rel))

	var winner := mini(second + lead, MAX_DOTS)
	# Greift die obere Schranke, rutscht der Zweite mit — der Vorsprung
	# bleibt dabei exakt erhalten und darf nicht von der Deckelung
	# aufgefressen werden.
	second = mini(second, winner - lead)

	var counts: Array[int] = [winner, second]
	while counts.size() < OPTION_COUNT:
		# Höchstens so viele wie der Zweite — damit bleibt der Sieger
		# eindeutig, und die schwerste Unterscheidung bleibt die gewollte
		# zwischen Sieger und Zweitem.
		counts.append(maxi(MIN_DOTS, second - r.next_int(0, 2)))

	r.shuffle(counts)
	return counts


## Verteilt [param count] Punkte überlappungsfrei auf das Raster.
##
## Gespeichert werden Zellennummer und Versatz, nicht Pixel: Die Felder sind
## auf jedem Gerät unterschiedlich groß, die Anordnung muss mitwachsen.
func _scatter(count: int, r: SeededRng) -> Dictionary:
	var pool: Array[int] = []
	for i in CELLS:
		pool.append(i)
	r.shuffle(pool)

	var cells: Array[int] = []
	var jitter: Array[Vector2] = []
	for i in mini(count, CELLS):
		cells.append(pool[i])
		# Versatz als Anteil des in der Zelle verfügbaren Spielraums (-1..1).
		jitter.append(Vector2(r.next_float_range(-1.0, 1.0), r.next_float_range(-1.0, 1.0)))

	return {"cells": cells, "jitter": jitter}


## Aufgabensignatur für Tests und die Server-Prüfung.
##
## Grafische Aufgaben brauchen keinen Fragetext — die Ansicht blendet ihn
## bei [method is_graphical] ohnehin aus. Statt das Feld leer zu lassen,
## steht hier eine kompakte Kennung der Aufgabe, mit der sich zwei Läufe
## ohne Rendern vergleichen lassen. Die Zahlen sind aufsteigend sortiert und
## verraten deshalb nicht, welches Feld gewinnt.
func _signature(counts: Array[int]) -> String:
	var sorted_counts := counts.duplicate()
	sorted_counts.sort()
	var parts: Array[String] = []
	for c in sorted_counts:
		parts.append(str(c))
	return "Punktzahlen " + "/".join(parts)


func is_graphical() -> bool:
	return true


# ---------------------------------------------------------------------------
# Darstellung
# ---------------------------------------------------------------------------

## Zeichnet die Regel als Bild: wenig Punkte, "<", viele Punkte — das volle
## Feld ist golden umrahmt. Ein Hinweis ohne Text, den auch jemand versteht,
## der das Tutorial verpasst hat.
func draw_task(canvas: Control, _task: MinigameTask) -> void:
	var size := canvas.size
	if size.x < 40.0 or size.y < 40.0:
		return

	var box_h := minf(size.y * 0.42, size.x * 0.20)
	var box_w := box_h * 1.7
	var gap := box_w * 0.30
	var ox := (size.x - (box_w * 2.0 + gap)) * 0.5
	var oy := (size.y - box_h) * 0.5

	var few: Array[Vector2] = [
		Vector2(0.22, 0.30), Vector2(0.58, 0.26),
		Vector2(0.34, 0.70), Vector2(0.72, 0.66),
	]
	var many: Array[Vector2] = [
		Vector2(0.14, 0.24), Vector2(0.36, 0.20), Vector2(0.58, 0.28), Vector2(0.80, 0.22),
		Vector2(0.24, 0.52), Vector2(0.48, 0.50), Vector2(0.70, 0.56),
		Vector2(0.16, 0.78), Vector2(0.40, 0.80), Vector2(0.66, 0.80),
	]

	_draw_hint_box(canvas, Rect2(Vector2(ox, oy), Vector2(box_w, box_h)), few, false)
	_draw_hint_box(canvas,
		Rect2(Vector2(ox + box_w + gap, oy), Vector2(box_w, box_h)), many, true)

	# Das Kleiner-als-Zeichen zwischen den Feldern, aus zwei Linien.
	var cx := ox + box_w + gap * 0.5
	var cy := oy + box_h * 0.5
	var arm := gap * 0.30
	var thick := maxf(3.0, arm * 0.28)
	canvas.draw_line(Vector2(cx + arm, cy - arm), Vector2(cx - arm, cy), HINT, thick)
	canvas.draw_line(Vector2(cx - arm, cy), Vector2(cx + arm, cy + arm), HINT, thick)


func _draw_hint_box(canvas: Control, box: Rect2, dots: Array[Vector2], winner: bool) -> void:
	canvas.draw_rect(box, PANEL, true)
	var border := ACCENT_BORDER if winner else PANEL_BORDER
	canvas.draw_rect(box, border, false, maxf(2.0, box.size.y * (0.05 if winner else 0.025)))

	var rad := box.size.y * 0.10
	for d in dots:
		canvas.draw_circle(box.position + d * box.size, rad, DOT)


## Zeichnet ein Antwortfeld mit seinen Punkten.
func draw_option(canvas: Control, task: MinigameTask, option: int) -> void:
	var fields: Array = task.draw_data.get("fields", [])
	if option < 0 or option >= fields.size():
		return

	var size := canvas.size
	if size.x < 16.0 or size.y < 16.0:
		return

	# Alles relativ zur Feldgröße — nie feste Pixelmaße, die Felder sind je
	# nach Gerät und Bildschirmseite unterschiedlich groß.
	var pad := minf(size.x, size.y) * 0.08
	var area := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0))
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return

	canvas.draw_rect(area, PANEL, true)
	canvas.draw_rect(area, PANEL_BORDER, false, maxf(2.0, minf(size.x, size.y) * 0.012))

	var field: Dictionary = fields[option]
	var cells: Array = field.get("cells", [])
	var jitter: Array = field.get("jitter", [])

	var cw := area.size.x / float(COLS)
	var ch := area.size.y / float(ROWS)
	var rad := minf(cw, ch) * DOT_FILL
	# Spielraum innerhalb der Zelle: so viel, dass der Punkt gerade noch
	# vollständig in ihr bleibt.
	var span := Vector2(cw * 0.5 - rad, ch * 0.5 - rad)

	for i in cells.size():
		var cell: int = cells[i]
		var col := cell % COLS
		var row := cell / COLS
		var off: Vector2 = jitter[i] if i < jitter.size() else Vector2.ZERO
		var center := area.position + Vector2(
			(float(col) + 0.5) * cw + off.x * span.x,
			(float(row) + 0.5) * ch + off.y * span.y)
		canvas.draw_circle(center, rad, DOT)
