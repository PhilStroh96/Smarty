extends Node

## Legt von jedem Minispiel der Registry einen Screenshot ab.
##
##     godot --path . --resolution 1920x1080 res://tools/screenshot_minigames.tscn
##
## Ohne --headless, sonst wird nichts gerendert.
##
## Die Logiktests prüfen, ob Aufgaben eindeutig und deterministisch sind.
## Ob man sie auch [i]lesen[/i] kann — Kontrast, Größen, Überlappungen,
## abgeschnittene Formen — sieht man nur im Bild.

const SEED := 20260724
const OUT_DIR := "user://shots"

## Frames zwischen Aufbau und Aufnahme. Ein Frame reicht nicht: Container
## brauchen einen Durchlauf, um ihre Kinder zu positionieren.
const SETTLE_FRAMES := 4


func _ready() -> void:
	_capture_all()


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for entry in MinigameRegistry.all():
		await _capture(entry, false)
		# Merkspiele zusätzlich während der Einprägephase aufnehmen —
		# das ist der Zustand, den die Fragephase danach nicht mehr zeigt.
		if entry["category"] == MinigameBase.Category.MERKEN:
			await _capture(entry, true)

	print("Fertig: %s" % ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit(0)


func _capture(entry: Dictionary, during_study: bool) -> void:
	var scene: PackedScene = load(entry["scene"])
	if scene == null:
		push_error("nicht ladbar: %s" % entry["scene"])
		return

	# Als CanvasLayer statt als Control-Hülle: Ein Control als Kind eines
	# einfachen Node bekommt keine Größe zugewiesen und würde die Ansicht
	# auf Minimalmaß zusammendrücken.
	var holder := CanvasLayer.new()
	add_child(holder)

	var game = scene.instantiate()
	game.setup(SEED)

	var view := MinigameView.new()
	holder.add_child(view)
	view.bind(game)
	holder.add_child(game)
	game.start()

	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	# Bei Merkspielen entweder mitten in der Einprägephase aufnehmen oder
	# danach — je nachdem, was geprüft werden soll.
	var task: MinigameTask = game.current_task()
	if task != null and task.study_seconds > 0.0:
		if during_study:
			await get_tree().create_timer(task.study_seconds * 0.4).timeout
		else:
			await get_tree().create_timer(task.study_seconds + 0.3).timeout
		for i in SETTLE_FRAMES:
			await get_tree().process_frame

	await RenderingServer.frame_post_draw

	var suffix := "_merkphase" if during_study else ""
	var path := "%s/%s%s.png" % [OUT_DIR, entry["id"], suffix]
	var img := get_viewport().get_texture().get_image()
	if img.save_png(path) == OK:
		print("  %s" % path)
	else:
		push_error("Screenshot fehlgeschlagen: %s" % path)

	holder.queue_free()
	await get_tree().process_frame
