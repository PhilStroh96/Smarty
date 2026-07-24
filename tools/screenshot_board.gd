extends Node

## Rendert die Brettszene und legt einen Screenshot ab.
##
##     godot --path . --resolution 1280x720 res://tools/screenshot_board.tscn
##
## Bewusst OHNE --headless: Der Headless-Renderer zeichnet nichts, ein
## Screenshot daraus wäre leer. Braucht also eine Desktop-Sitzung.
##
## Zweck ist die visuelle Kontrolle des Bretts ohne den Editor — Isometrie,
## Y-Sortierung und Figurenversatz lassen sich in keinem Logiktest prüfen.

const SCENE := "res://board/board_scene.tscn"
const OUT_PATH := "user://board_screenshot.png"

## Wartezeit vor der Aufnahme. Muss reichen, damit die erste
## Figurenbewegung angelaufen ist.
const SETTLE_SECONDS := 2.5


func _ready() -> void:
	_capture()


func _capture() -> void:
	var packed: PackedScene = load(SCENE)
	if packed == null:
		push_error("Szene nicht ladbar: %s" % SCENE)
		get_tree().quit(1)
		return

	add_child(packed.instantiate())

	await get_tree().create_timer(SETTLE_SECONDS).timeout
	# Ein zusätzlicher Frame, damit die Aufnahme das fertig gezeichnete
	# Bild erwischt und nicht den Stand davor.
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("Screenshot fehlgeschlagen: %d" % err)
		get_tree().quit(1)
		return

	print("Screenshot: %s" % ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)
