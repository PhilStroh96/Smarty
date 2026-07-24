extends Control

## Startszene für M0: Geräte-Diagnose und Determinismus-Selbsttest.
##
## Zweck: Verifizieren, dass der Build auf dem echten Handy läuft, die
## Safe Area korrekt erkannt wird — und vor allem, dass [SeededRng] auf
## Android dieselben Zahlen liefert wie auf dem Windows-Rechner.
##
## Der ganze Netcode-Ansatz (PLAN.md §2.1) steht und fällt damit. Wenn der
## Fingerprint zwischen zwei Geräten abweicht, sehen Spieler unterschiedliche
## Aufgaben und die Server-Validierung lehnt korrekte Antworten ab. Diesen
## Fehler will man in Woche 1 finden, nicht in Monat 6.

const DIAG_SEED := 20260724

var _fps_label: Label
var _safe_area_rect: ColorRect


func _ready() -> void:
	_build_ui()


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_update_safe_area()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("#1b1b2f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Visualisiert die Safe Area — alles außerhalb kann von Notch,
	# Dynamic Island oder Gestenleiste verdeckt werden.
	_safe_area_rect = ColorRect.new()
	_safe_area_rect.color = Color(0.2, 0.9, 0.5, 0.08)
	_safe_area_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe_area_rect)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var scroll := ScrollContainer.new()
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	vbox.add_child(_heading("Mobile Smarty — M0 Diagnose"))
	vbox.add_child(_line("Godot %s" % Engine.get_version_info()["string"]))
	vbox.add_child(_line("Renderer: %s" % RenderingServer.get_current_rendering_method()))
	vbox.add_child(_line("Plattform: %s" % OS.get_name()))
	vbox.add_child(_line("Modell: %s" % OS.get_model_name()))
	vbox.add_child(_line("Viewport: %s" % str(get_viewport_rect().size)))
	vbox.add_child(_line("Bildschirm: %s" % str(DisplayServer.screen_get_size())))
	vbox.add_child(_line("Safe Area: %s" % str(DisplayServer.get_display_safe_area())))
	vbox.add_child(_line("DPI: %d" % DisplayServer.screen_get_dpi()))

	_fps_label = _line("FPS: –")
	vbox.add_child(_fps_label)

	vbox.add_child(_spacer())
	vbox.add_child(_heading("Determinismus-Selbsttest"))

	for result in _run_determinism_tests():
		vbox.add_child(_line(result["text"], result["ok"]))

	vbox.add_child(_spacer())
	vbox.add_child(_line(
		"Fingerprint auf jedem Zielgerät vergleichen.\n"
		+ "Weicht er ab, ist der Netcode-Ansatz gebrochen.", true))

	vbox.add_child(_spacer())
	var start := Button.new()
	start.text = "Partie starten"
	start.custom_minimum_size = Vector2(0, 96)
	start.add_theme_font_size_override("font_size", 36)
	start.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://board/board_scene.tscn")
	)
	vbox.add_child(start)


## Prüft die Eigenschaften, auf denen der Netcode aufbaut.
func _run_determinism_tests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	# 1. Gleicher Seed -> gleiche Folge.
	var a := SeededRng.new(DIAG_SEED)
	var b := SeededRng.new(DIAG_SEED)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	for i in 32:
		seq_a.append(a.next_int(0, 999))
		seq_b.append(b.next_int(0, 999))
	out.append(_check("Gleicher Seed -> gleiche Folge", seq_a == seq_b))

	# 2. reset() stellt den Ausgangszustand wieder her.
	a.reset(DIAG_SEED)
	var seq_c: Array[int] = []
	for i in 32:
		seq_c.append(a.next_int(0, 999))
	out.append(_check("reset() ist reproduzierbar", seq_a == seq_c))

	# 3. fork() ist stabil und unabhängig von der Aufrufreihenfolge.
	var base := SeededRng.new(DIAG_SEED)
	var f1 := base.fork(7).next_int(0, 9999)
	var _noise := base.next_int(0, 100)  # verändert den Elternzustand
	var f2 := base.fork(7).next_int(0, 9999)
	out.append(_check("fork() ist reihenfolgeunabhängig", f1 == f2))

	# 4. shuffle() ist deterministisch.
	var src := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var s1 := SeededRng.new(DIAG_SEED).shuffled(src)
	var s2 := SeededRng.new(DIAG_SEED).shuffled(src)
	out.append(_check("shuffle() ist deterministisch", s1 == s2))

	# 5. Floats bleiben im erwarteten Bereich.
	var float_ok := true
	var fr := SeededRng.new(DIAG_SEED)
	for i in 256:
		var v := fr.next_float()
		if v < 0.0 or v >= 1.0:
			float_ok = false
			break
	out.append(_check("next_float() in [0, 1)", float_ok))

	# 6. Plattform-Fingerprint — der eigentliche Prüfwert.
	var fp := 0
	var fpr := SeededRng.new(DIAG_SEED)
	for i in 1000:
		fp = SeededRng.mix(fp, fpr.next_int(0, 65535))
	out.append({"text": "Fingerprint: %d" % fp, "ok": true})

	return out


func _check(label: String, ok: bool) -> Dictionary:
	return {"text": ("%s  %s" % ["OK  " if ok else "FEHLER", label]), "ok": ok}


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color("#ffd369"))
	return l


func _line(text: String, ok: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color("#e8e8e8") if ok else Color("#ff5c5c"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 20)
	return c


func _update_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return
	# Bildschirmkoordinaten auf den Viewport umrechnen.
	var vp := get_viewport_rect().size
	var scale := Vector2(vp.x / float(screen.x), vp.y / float(screen.y))
	_safe_area_rect.position = Vector2(safe.position) * scale
	_safe_area_rect.size = Vector2(safe.size) * scale
