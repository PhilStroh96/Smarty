class_name MinigameView
extends Control

## Stellt ein [QuizMinigame] dar: Aufgabe oben, Antwortfelder unten,
## Zeitbalken und Punktestand.
##
## Die Darstellung ist bewusst generisch. Ein Minispiel liefert Aufgaben
## und – falls grafisch – Zeichenanweisungen; wie das auf dem Schirm
## angeordnet wird, entscheidet allein diese Klasse. Dadurch sehen alle
## Minispiele gleich aus und der Spieler muss sich pro Spiel nur die Regel
## merken, nicht die Bedienung.

signal option_chosen(index: int)

const BG := Color("#1b1b2f")
const ACCENT := Color("#ffd369")
const CORRECT := Color("#4ade80")
const WRONG := Color("#e5484d")

## Mindesthöhe eines Antwortfelds. Deutlich über den 48 dp aus den
## Touch-Richtlinien: Unter Zeitdruck wird ungenauer getippt (PLAN.md §2.6).
const OPTION_MIN_HEIGHT := 150

## Wie lange ein Antwortfeld nach dem Tippen eingefärbt bleibt.
const FEEDBACK_TIME := 0.22

var game: QuizMinigame

var _time_bar: ProgressBar
var _score_label: Label
var _prompt_label: Label
var _task_canvas: Control
var _option_buttons: Array[Button] = []
var _option_canvases: Array[Control] = []
var _grid: GridContainer
var _locked: bool = false


func _ready() -> void:
	# set_anchors_AND_OFFSETS_preset, nicht nur set_anchors_preset: Letzteres
	# setzt die Anker, lässt die Offsets aber stehen. Das Control behält
	# dann seine Minimalgröße und der ganze Inhalt klebt in der linken
	# oberen Ecke, statt den Bildschirm zu füllen.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _process(_delta: float) -> void:
	if game == null or not game.is_running():
		return
	_time_bar.value = game.time_left()
	# Der Balken wird rot, wenn es knapp wird — Zeitdruck muss man sehen,
	# nicht ausrechnen.
	var frac := game.time_left() / maxf(game.duration_sec, 0.001)
	_time_bar.modulate = WRONG if frac < 0.2 else Color.WHITE


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)

	# --- Kopf: Zeit und Punkte ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)

	_time_bar = ProgressBar.new()
	_time_bar.show_percentage = false
	_time_bar.custom_minimum_size = Vector2(0, 28)
	_time_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_time_bar)

	_score_label = _label("0", 34, ACCENT)
	head.add_child(_score_label)

	# --- Mitte: die Aufgabe ---
	var task_box := PanelContainer.new()
	task_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(task_box)

	# Das Label füllt die ganze Breite und zentriert seinen Text. NICHT in
	# einem CenterContainer: der schrumpft ein autowrap-Label auf seine
	# Minimalbreite (fast null), worauf der Text zeichenweise senkrecht
	# umbricht — auf schmaleren Geräten sofort sichtbar. So bleibt "41 − 19"
	# eine Zeile und die Aufgabenfläche bläht sich nicht auf.
	_prompt_label = _label("", 88, Color.WHITE)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_box.add_child(_prompt_label)

	_task_canvas = Control.new()
	_task_canvas.custom_minimum_size = Vector2(600, 300)
	_task_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_canvas.draw.connect(_on_task_canvas_draw)
	task_box.add_child(_task_canvas)

	# --- Fuß: Antwortfelder ---
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 20)
	col.add_child(_grid)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# Standardmäßig KEIN Umbruch: kurze Labels (Punktestand) würden in engen
	# Containern sonst zeichenweise senkrecht umbrechen. Wer Umbruch braucht,
	# schaltet ihn gezielt ein (siehe Aufgaben-Label).
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## Verbindet die Ansicht mit einem Minispiel.
func bind(p_game: QuizMinigame) -> void:
	game = p_game
	_time_bar.max_value = game.duration_sec
	_time_bar.value = game.duration_sec
	game.task_changed.connect(_show_task)
	game.finished.connect(func(_r: MinigameResult) -> void: _set_enabled(false))
	_prompt_label.visible = not game.is_graphical()
	_task_canvas.visible = game.is_graphical()

	# Bei grafischen Spielen teilen sich Aufgabe und Antworten den Platz.
	# Sonst bekommt die Aufgabe fast die ganze Höhe und die Antwortformen
	# werden so klein, dass der Vergleich am Sehen scheitert statt am
	# Denken. Textantworten brauchen das nicht — ein Wort ist lesbar,
	# egal wie viel Platz drumherum ist.
	if game.is_graphical():
		_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_grid.size_flags_stretch_ratio = 1.0


func _show_task(task: MinigameTask, _index: int) -> void:
	_locked = false
	_rebuild_options(task)
	_score_label.text = str(game.get_result().score)

	if task.study_seconds > 0.0:
		await _run_study_phase(task)
	else:
		game.in_study_phase = false
		_prompt_label.text = task.prompt
		_task_canvas.queue_redraw()


## Zeigt die Aufgabe zum Einprägen, blendet sie aus und gibt dann die
## Antworten frei.
func _run_study_phase(task: MinigameTask) -> void:
	game.in_study_phase = true
	_prompt_label.text = task.study_prompt
	_task_canvas.queue_redraw()
	_set_options_visible(false)

	await get_tree().create_timer(task.study_seconds).timeout

	# Zwischenprüfung: Wenn das Spiel während des Einprägens abgelaufen
	# ist oder schon die nächste Aufgabe läuft, hier nichts mehr anfassen.
	if game == null or not game.is_running() or game.current_task() != task:
		return

	game.in_study_phase = false
	_prompt_label.text = task.prompt
	_task_canvas.queue_redraw()
	_set_options_visible(true)


## Blendet die Antwortfelder aus, ohne das Layout zu verändern.
##
## Bewusst nicht über [code]visible[/code]: Der Container nimmt unsichtbare
## Knöpfe aus dem Layout, wodurch die Aufgabenfläche in die Höhe springt.
## Bei Merkaufgaben säße die Symbolreihe beim Einprägen dann an einer
## anderen Stelle als die Antworten danach — man würde sich Positionen
## merken, die nachher nicht mehr stimmen.
func _set_options_visible(on: bool) -> void:
	var task := game.current_task() if game != null else null
	var needed := task.answer_count() if task != null else 0
	for i in _option_buttons.size():
		var in_use := i < needed
		_option_buttons[i].visible = in_use
		_option_buttons[i].modulate.a = 1.0 if (on and in_use) else 0.0
		_option_buttons[i].disabled = not (on and in_use)


func _rebuild_options(task: MinigameTask) -> void:
	var needed := task.answer_count()

	# Anzahl der Felder kann pro Aufgabe wechseln — Knöpfe nachziehen.
	while _option_buttons.size() < needed:
		var idx := _option_buttons.size()
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, OPTION_MIN_HEIGHT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 52)
		b.pressed.connect(_on_option_pressed.bind(idx))
		_grid.add_child(b)
		_option_buttons.append(b)

		var canvas := Control.new()
		canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.draw.connect(_on_option_canvas_draw.bind(idx))
		b.add_child(canvas)
		_option_canvases.append(canvas)

	for i in _option_buttons.size():
		var visible_now := i < needed
		_option_buttons[i].visible = visible_now
		_option_buttons[i].disabled = false
		_option_buttons[i].modulate = Color.WHITE
		_option_buttons[i].modulate.a = 1.0
		if visible_now:
			_option_buttons[i].text = task.options[i] if i < task.options.size() else ""
			_option_canvases[i].visible = game.is_graphical()
			_option_canvases[i].queue_redraw()

	# Bei mehr als zwei Antworten zweispaltig, sonst nebeneinander.
	_grid.columns = 2 if needed > 2 else maxi(needed, 1)


func _on_option_pressed(index: int) -> void:
	if game == null or _locked or not game.is_running():
		return
	# Sperren, bis das Feedback durch ist: Ohne das kann man sich per
	# Dauerfeuer durch die Aufgaben tippen und trifft statistisch oft genug.
	_locked = true

	var task := game.current_task()
	var was_correct := game.answer(index)

	if index < _option_buttons.size():
		_option_buttons[index].modulate = CORRECT if was_correct else WRONG
	# Bei falscher Antwort die richtige zeigen — sonst lernt niemand dazu.
	if not was_correct and task != null and task.correct < _option_buttons.size():
		_option_buttons[task.correct].modulate = CORRECT

	option_chosen.emit(index)
	await get_tree().create_timer(FEEDBACK_TIME).timeout
	_locked = false


func _on_task_canvas_draw() -> void:
	if game != null and game.current_task() != null:
		game.draw_task(_task_canvas, game.current_task())


func _on_option_canvas_draw(index: int) -> void:
	if game == null or game.current_task() == null:
		return
	if index < _option_canvases.size():
		game.draw_option(_option_canvases[index], game.current_task(), index)


func _set_enabled(on: bool) -> void:
	for b in _option_buttons:
		b.disabled = not on
