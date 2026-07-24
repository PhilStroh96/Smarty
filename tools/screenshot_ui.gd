extends Node

## Screenshots der UI-Bildschirme (Menü, Lobby) für die visuelle Kontrolle.
##
##     godot --path . --resolution 1920x1080 res://tools/screenshot_ui.tscn
##
## Ohne --headless (der rendert nicht). Ablage unter user://shots.

const OUT_DIR := "user://shots"
const SETTLE_FRAMES := 6


func _ready() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	await _shot(load("res://ui/main_menu.tscn").instantiate(), "menu_main", -1)
	await _shot(load("res://ui/lobby_screen.tscn").instantiate(), "menu_lobby_choice", -1)
	# Lobby in der Erstellen-Ansicht (View.CREATE = 1).
	await _shot(load("res://ui/lobby_screen.tscn").instantiate(), "menu_lobby_create", 1)

	print("Fertig: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _shot(scene: Node, name: String, view: int) -> void:
	add_child(scene)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	if view >= 0 and scene.has_method("_show"):
		scene.call("_show", view)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var path := "%s/%s.png" % [OUT_DIR, name]
	var img := get_viewport().get_texture().get_image()
	if img.save_png(path) == OK:
		print("  %s" % path)
	scene.queue_free()
	await get_tree().process_frame
