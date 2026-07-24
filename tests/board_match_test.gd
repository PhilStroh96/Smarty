extends Node

## Spielt komplette Partien headless durch — ohne Grafik, ohne Animation.
##
##     godot --headless --path . res://tests/board_match_test.tscn
##
## Exit-Code 0 = alles grün, 1 = Fehler.
##
## [b]Warum eine Szene und kein --script:[/b] Im Modus [code]--script[/code]
## startet Godot ohne Autoloads, und [GameState] wäre schlicht nicht
## vorhanden. Als Hauptszene geladen steht die volle Projektumgebung.
##
## Der wichtigste Test hier ist der dritte: Zwei Partien mit demselben Seed
## müssen Zug für Zug identisch verlaufen. Das ist die Eigenschaft, auf der
## in M3 die serverseitige Validierung aufsetzt (PLAN.md §2.1) — bricht sie,
## laufen Online-Partien auseinander.

const SEED_A := 4242
const SEED_B := 9001
const ROUNDS := 12
const PLAYERS := 4

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_run()


func _run() -> void:
	print("Brett-Partietest — Godot %s" % Engine.get_version_info()["string"])
	print("")

	var run_a := await _play(SEED_A)
	var run_b := await _play(SEED_A)
	var run_c := await _play(SEED_B)

	_check("Partie läuft bis zum Ende durch", run_a["rounds"] == ROUNDS)
	_check("Alle Spieler haben gezogen", run_a["turns"] == ROUNDS * PLAYERS)
	_check("Gleicher Seed -> identischer Verlauf", run_a["trace"] == run_b["trace"])
	_check("Anderer Seed -> anderer Verlauf", run_a["trace"] != run_c["trace"])
	_check("Würfel immer zwischen 1 und 6", run_a["dice_ok"])
	_check("Münzen nie negativ", run_a["coins_ok"])
	_check("Feldpositionen immer im Ring", run_a["pos_ok"])
	_check("Es wurden Sterne gekauft", run_a["stars_total"] > 0)
	_check("Startfeld-Prämie wurde ausgezahlt", run_a["start_bonus_count"] > 0)

	print("")
	print("Endstand Lauf A (Seed %d):" % SEED_A)
	for line in run_a["standings"]:
		print("  " + line)

	print("")
	print("%d/%d Prüfungen bestanden." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


## Spielt eine komplette Partie und gibt Kennzahlen plus einen
## Verlaufsprotokoll zurück.
func _play(seed: int) -> Dictionary:
	var players: Array[PlayerInfo] = []
	for i in PLAYERS:
		var p := PlayerInfo.new(StringName("p%d" % i), "P%d" % i)
		p.is_ai = true
		players.append(p)
	GameState.start_match(GameState.Mode.SOLO, players, seed, ROUNDS)

	var board := BoardMap.new()
	add_child(board)
	board.build(TestMap.build_fields())

	var turns := TurnManager.new()
	add_child(turns)
	# Ohne Figuren und ohne Taktung: reine Datenpartie, läuft in
	# Millisekunden statt in Minuten.
	turns.setup(board, [])
	turns.auto_play = true
	turns.pace = 0.0

	var trace: Array[String] = []
	var field_count := board.size()

	# Zähler und Flags stecken in einem Dictionary, nicht in lokalen
	# Variablen: GDScript-Lambdas fangen Locals BY VALUE ein. Ein
	# "turn_count += 1" in der Closure würde nur deren eigene Kopie
	# erhöhen und hier draußen immer 0 hinterlassen. Dictionaries und
	# Arrays sind dagegen Referenzen und funktionieren wie erwartet.
	var stats := {
		"turns": 0,
		"start_bonus": 0,
		"dice_ok": true,
		"pos_ok": true,
		"coins_ok": true,
	}

	turns.dice_rolled.connect(func(i: int, v: int) -> void:
		stats["turns"] += 1
		if v < 1 or v > 6:
			stats["dice_ok"] = false
		trace.append("r%d p%d d%d" % [GameState.current_round, i, v])
	)
	turns.player_moved.connect(func(i: int, f: int) -> void:
		if f < 0 or f >= field_count:
			stats["pos_ok"] = false
		var p: PlayerInfo = GameState.players[i]
		if p.coins < 0:
			stats["coins_ok"] = false
		trace.append("  -> f%d c%d s%d" % [f, p.coins, p.stars])
	)
	turns.field_resolved.connect(func(_i: int, msg: String) -> void:
		if msg.begins_with("Über Start"):
			stats["start_bonus"] += 1
	)

	await turns.run_match()

	var stars_total := 0
	var standings: Array[String] = []
	for p in GameState.standings():
		stars_total += p.stars
		standings.append("%s: %d Sterne, %d Münzen, Feld %d" % [
			p.display_name, p.stars, p.coins, p.board_position
		])

	var result := {
		"rounds": GameState.current_round,
		"turns": stats["turns"],
		"trace": trace,
		"dice_ok": stats["dice_ok"],
		"pos_ok": stats["pos_ok"],
		"coins_ok": stats["coins_ok"],
		"stars_total": stars_total,
		"start_bonus_count": stats["start_bonus"],
		"standings": standings,
	}

	board.queue_free()
	turns.queue_free()
	await get_tree().process_frame
	return result


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  OK      %s" % label)
	else:
		_failures += 1
		print("  FEHLER  %s" % label)
