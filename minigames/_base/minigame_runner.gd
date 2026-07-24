class_name MinigameRunner
extends Control

## Führt ein Minispiel von der Erklärung bis zum Ergebnis aus.
##
## Ablauf: Titel und Regel -> Countdown -> Spiel -> Ergebnis.
##
## Die Erklärungsphase ist kurz und die Regel steht in einem Satz. Bei vier
## Spielern, die gleichzeitig warten, ist jede zusätzliche Sekunde
## Erklärung eine Sekunde, in der drei Leute nichts tun (PLAN.md §1.3).

signal finished(result: MinigameResult)

## Wie lange Titel und Regel stehen bleiben.
const INTRO_TIME := 2.6
## Countdown-Schritte vor dem Start.
const COUNTDOWN_FROM := 3

const BG := Color("#1b1b2f")
const ACCENT := Color("#ffd369")

var _game: QuizMinigame
var _view: MinigameView
var _overlay: Control
var _big_label: Label
var _sub_label: Label


func _ready() -> void:
	# Anker UND Offsets — sonst bleibt das Control auf Minimalgröße
	# und das Minispiel füllt den Bildschirm nicht.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Lädt ein Minispiel und spielt es durch. Muss awaited werden.
func run(entry: Dictionary, seed: int, difficulty: float = 0.5) -> MinigameResult:
	var scene: PackedScene = load(entry["scene"])
	if scene == null:
		push_error("Minispiel nicht ladbar: %s" % entry["scene"])
		return MinigameResult.new()

	_game = scene.instantiate()
	_game.setup(seed, difficulty)

	_view = MinigameView.new()
	add_child(_view)
	_view.bind(_game)
	add_child(_game)

	_build_overlay()
	await _show_intro(entry)
	await _countdown()
	_overlay.visible = false

	_game.start()
	var result: MinigameResult = await _game.finished

	await _show_outro(result)
	finished.emit(result)
	return result


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	center.add_child(col)

	_big_label = Label.new()
	_big_label.add_theme_font_size_override("font_size", 96)
	_big_label.add_theme_color_override("font_color", ACCENT)
	_big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_big_label)

	_sub_label = Label.new()
	_sub_label.add_theme_font_size_override("font_size", 44)
	_sub_label.add_theme_color_override("font_color", Color.WHITE)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_label.custom_minimum_size = Vector2(1100, 0)
	col.add_child(_sub_label)


func _show_intro(entry: Dictionary) -> void:
	_big_label.text = entry.get("title", "Minispiel")
	_sub_label.text = _game.tutorial_text
	await get_tree().create_timer(INTRO_TIME).timeout


func _countdown() -> void:
	_sub_label.text = ""
	for i in range(COUNTDOWN_FROM, 0, -1):
		_big_label.text = str(i)
		await get_tree().create_timer(0.7).timeout
	_big_label.text = "Los!"
	await get_tree().create_timer(0.4).timeout


func _show_outro(result: MinigameResult) -> void:
	_overlay.visible = true
	_big_label.text = "%d Punkte" % result.score
	_sub_label.text = "%d richtig, %d falsch" % [result.correct, result.wrong]
	await get_tree().create_timer(1.8).timeout
