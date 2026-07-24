extends Control

## Das Hauptmenü — der neue Einstieg der App (ersetzt den Diagnose-Bildschirm
## als Startszene).
##
## Per Code aufgebaut wie die übrige UI; das echte Design kommt in M4. Wichtig
## sind hier nur der Fluss und mobiltaugliche Touch-Ziele.

const BOARD_SCENE := "res://board/board_scene.tscn"
const LOBBY_SCENE := "res://ui/lobby_screen.tscn"
const BOOTSTRAP_SCENE := "res://core/bootstrap.tscn"

const BG := Color("#1b1b2f")
const ACCENT := Color("#ffd369")
const TOUCH_MIN := 110


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Mobile Smarty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", ACCENT)
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Das Partyspiel, bei dem Köpfchen gewinnt"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 32)
	subtitle.add_theme_color_override("font_color", Color("#c8c8d8"))
	col.add_child(subtitle)

	col.add_child(_spacer(40))

	col.add_child(_menu_button("Lokal spielen", _on_local))
	col.add_child(_menu_button("Online spielen", _on_online))
	col.add_child(_menu_button("Diagnose", _on_diagnose, false))


func _menu_button(text: String, cb: Callable, primary: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH_MIN if primary else TOUCH_MIN * 0.8)
	b.add_theme_font_size_override("font_size", 40 if primary else 30)
	b.pressed.connect(cb)
	return b


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_local() -> void:
	# Lokale Solo-Partie: kein Kontext, die Brettszene baut ihn selbst.
	MatchSetup.clear()
	get_tree().change_scene_to_file(BOARD_SCENE)


func _on_online() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_diagnose() -> void:
	get_tree().change_scene_to_file(BOOTSTRAP_SCENE)
