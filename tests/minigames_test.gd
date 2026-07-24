extends Node

## Prüft jedes Minispiel aus der [MinigameRegistry] gegen dieselben Regeln.
##
##     godot --headless --path . res://tests/minigames_test.tscn
##
## Exit-Code 0 = alles grün, 1 = Fehler.
##
## Generisch statt pro Spiel: Ein neues Minispiel wird automatisch
## mitgeprüft, sobald es in der Registry steht. Die Regeln hier sind die
## Mindestanforderungen, an denen sich jedes Minispiel messen lassen muss —
## vor allem der Determinismus, ohne den die Server-Validierung in M3 nicht
## funktionieren kann (PLAN.md §2.1).

const SEED_A := 13579
const SEED_B := 24680

## So viele Aufgaben werden je Spiel geprüft.
const SAMPLE := 40

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_run()


func _run() -> void:
	print("Minispiel-Test — %d Spiele in der Registry" % MinigameRegistry.all().size())
	print("")

	_check("Registry ist nicht leer", not MinigameRegistry.all().is_empty())
	_test_registry_integrity()
	_test_category_coverage()
	_test_picker()

	for entry in MinigameRegistry.all():
		print("")
		print("--- %s (%s) ---" % [entry["title"], entry["id"]])
		await _test_game(entry)

	print("")
	print("%d/%d Prüfungen bestanden." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_registry_integrity() -> void:
	var ids := {}
	var scenes_ok := true
	var dupes := false
	for e in MinigameRegistry.all():
		if ids.has(e["id"]):
			dupes = true
		ids[e["id"]] = true
		if not ResourceLoader.exists(e["scene"]):
			scenes_ok = false
			print("  fehlende Szene: %s" % e["scene"])
	_check("Alle Minispiel-IDs sind eindeutig", not dupes)
	_check("Alle Szenenpfade existieren", scenes_ok)


func _test_category_coverage() -> void:
	# Jede Kategorie braucht mindestens ein Spiel — sonst ist eine
	# Fähigkeit gar nicht vertreten und die Partie wird einseitig
	# (PLAN.md §1.3).
	var missing: Array[String] = []
	for c in [
		MinigameBase.Category.ERKENNEN, MinigameBase.Category.MERKEN,
		MinigameBase.Category.ANALYSIEREN, MinigameBase.Category.RECHNEN,
		MinigameBase.Category.VORSTELLEN,
	]:
		if MinigameRegistry.by_category(c).is_empty():
			missing.append(str(c))
	if not missing.is_empty():
		print("  Kategorien ohne Spiel: %s" % ", ".join(missing))
	_check("Alle fünf Kategorien sind belegt", missing.is_empty())


func _test_picker() -> void:
	# Gleicher Seed und gleiche Runde müssen dasselbe Spiel wählen,
	# sonst laden die Clients unterschiedliche Minispiele.
	var a := MinigameRegistry.pick(4242, 3)
	var b := MinigameRegistry.pick(4242, 3)
	_check("Auswahl ist deterministisch", a.get("id") == b.get("id"))

	# Und die Vermeidung von Wiederholungen muss greifen.
	var recent := [a.get("id")]
	var c := MinigameRegistry.pick(4242, 3, recent)
	var only_one := MinigameRegistry.all().size() <= 1
	_check("Zuletzt gespieltes wird vermieden",
		only_one or c.get("id") != a.get("id"))


func _test_game(entry: Dictionary) -> void:
	var scene: PackedScene = load(entry["scene"])
	if scene == null:
		_check("%s: Szene ladbar" % entry["id"], false)
		return

	var game_a = scene.instantiate()
	var game_b = scene.instantiate()
	add_child(game_a)
	add_child(game_b)

	_check("%s: erbt von MinigameBase" % entry["id"], game_a is MinigameBase)
	_check("%s: Kategorie stimmt mit Registry überein" % entry["id"],
		game_a.category == entry["category"])
	_check("%s: Regel ist gesetzt" % entry["id"], game_a.tutorial_text.strip_edges() != "")
	# Die Regel muss in einen Satz passen. Was länger ist, liest bei einem
	# 3-Sekunden-Intro niemand.
	_check("%s: Regel ist kurz genug (%d Zeichen)" % [entry["id"], game_a.tutorial_text.length()],
		game_a.tutorial_text.length() <= 90)
	_check("%s: Dauer im Zielkorridor 30-90 s" % entry["id"],
		game_a.duration_sec >= 30.0 and game_a.duration_sec <= 90.0)

	game_a.setup(SEED_A)
	game_b.setup(SEED_A)

	if not (game_a is QuizMinigame):
		# Spiele mit eigenem Rhythmus erfüllen nur den Grundvertrag.
		game_a.queue_free()
		game_b.queue_free()
		return

	var count: int = mini(SAMPLE, game_a.tasks.size())
	_check("%s: erzeugt Aufgaben" % entry["id"], count > 0)
	if count == 0:
		game_a.queue_free()
		game_b.queue_free()
		return

	var deterministic := true
	var valid_index := true
	var enough_options := true
	var no_dupes := true
	var has_prompt := true

	for i in count:
		var ta: MinigameTask = game_a.tasks[i]
		var tb: MinigameTask = game_b.tasks[i]

		if ta.prompt != tb.prompt or ta.options != tb.options or ta.correct != tb.correct:
			deterministic = false
		if ta.correct < 0 or ta.correct >= ta.answer_count():
			valid_index = false
		if ta.answer_count() < 2:
			enough_options = false
		# Doppelte Antwortoptionen machen eine Aufgabe mehrdeutig: Zwei
		# gleiche Texte, einer gilt als falsch. Das ist unfair, nicht schwer.
		if not ta.options.is_empty():
			var seen := {}
			for o in ta.options:
				if seen.has(o):
					no_dupes = false
				seen[o] = true
		# Rein grafische Spiele dürfen ohne Text auskommen.
		if not game_a.is_graphical() and ta.prompt.strip_edges() == "":
			has_prompt = false

	_check("%s: Aufgaben sind deterministisch" % entry["id"], deterministic)
	_check("%s: correct zeigt auf gültige Antwort" % entry["id"], valid_index)
	_check("%s: mindestens zwei Antworten" % entry["id"], enough_options)
	_check("%s: keine doppelten Antworten" % entry["id"], no_dupes)
	_check("%s: Aufgaben haben Text oder sind grafisch" % entry["id"], has_prompt)

	# Anderer Seed muss andere Aufgaben liefern, sonst spielt jede Partie
	# exakt dieselbe Folge.
	var game_c = scene.instantiate()
	add_child(game_c)
	game_c.setup(SEED_B)
	var differs := false
	for i in count:
		if game_c.tasks[i].prompt != game_a.tasks[i].prompt:
			differs = true
			break
	_check("%s: anderer Seed -> andere Aufgaben" % entry["id"], differs)

	await _test_playthrough(entry, scene)

	game_a.queue_free()
	game_b.queue_free()
	game_c.queue_free()


## Spielt das Minispiel durch und prüft die Punktelogik.
func _test_playthrough(entry: Dictionary, scene: PackedScene) -> void:
	var game = scene.instantiate()
	add_child(game)
	game.setup(SEED_A)
	game.start()

	# Alle Aufgaben richtig beantworten.
	var answered := 0
	while game.is_running() and answered < 20:
		var t: MinigameTask = game.current_task()
		if t == null:
			break
		game.answer(t.correct)
		answered += 1

	var res: MinigameResult = game.get_result()
	_check("%s: richtige Antworten geben Punkte" % entry["id"], res.score > 0)
	_check("%s: richtige Antworten werden gezählt" % entry["id"], res.correct == answered)
	_check("%s: keine falschen gezählt" % entry["id"], res.wrong == 0)

	game.queue_free()

	# Und dasselbe mit lauter falschen Antworten.
	var game2 = scene.instantiate()
	add_child(game2)
	game2.setup(SEED_A)
	game2.start()
	var wrong_count := 0
	while game2.is_running() and wrong_count < 10:
		var t: MinigameTask = game2.current_task()
		if t == null:
			break
		# Irgendeine Antwort, die nicht die richtige ist.
		var wrong_choice := (t.correct + 1) % maxi(t.answer_count(), 1)
		game2.answer(wrong_choice)
		wrong_count += 1

	var res2: MinigameResult = game2.get_result()
	_check("%s: falsche Antworten werden gezählt" % entry["id"], res2.wrong == wrong_count)
	# Punkte dürfen nie unter null fallen, sonst wirkt eine schwache
	# Runde wie eine Bestrafung statt wie ein Rückstand.
	_check("%s: Punkte bleiben bei mindestens 0" % entry["id"], res2.score >= 0)
	game2.queue_free()


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  OK      %s" % label)
	else:
		_failures += 1
		print("  FEHLER  %s" % label)
