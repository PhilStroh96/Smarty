extends Node

## Spielt komplette Partien über den [MatchServer] durch — die autoritative
## Logik, ohne Grafik und ohne Animation.
##
##     godot --headless --path . res://tests/board_match_test.tscn
##
## Exit-Code 0 = alles grün, 1 = Fehler.
##
## Weil der Server rein synchron ist (er rechnet, er animiert nicht), läuft
## eine ganze Partie in einem Rutsch durch — kein await, keine Wartezeit.
##
## Die wichtigsten Prüfungen betreffen den Netcode-Kern (PLAN.md §2.1):
## Zwei Partien mit demselben Seed müssen [i]Event für Event[/i] identisch
## verlaufen. Darauf setzt die serverseitige Validierung auf; bricht sie,
## laufen Online-Partien auseinander.

const SEED_A := 4242
const SEED_B := 9001
const ROUNDS := 12
const PLAYERS := 4
const NOW := 0

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	print("Netcode-Partietest — Godot %s" % Engine.get_version_info()["string"])
	print("")

	var run_a := _run_ai_match(SEED_A)
	var run_b := _run_ai_match(SEED_A)
	var run_c := _run_ai_match(SEED_B)

	# --- Determinismus ---
	_check("Gleicher Seed -> identischer Event-Strom",
		run_a["stream"] == run_b["stream"])
	_check("Anderer Seed -> anderer Event-Strom",
		run_a["stream"] != run_c["stream"])

	# --- Vollständigkeit ---
	_check("Partie endet mit MATCH_ENDED", run_a["ended"])
	_check("Alle Spieler haben in jeder Runde gezogen",
		run_a["turns"] == ROUNDS * PLAYERS)
	_check("Nach jeder Runde lief ein Minispiel", run_a["minigames"] == ROUNDS)

	# --- Invarianten ---
	_check("Würfel immer zwischen 1 und 6", run_a["dice_ok"])
	_check("Feldpositionen immer im Ring", run_a["pos_ok"])
	_check("Münzen nie negativ", run_a["coins_ok"])
	_check("Startfeld-Prämie wurde ausgezahlt", run_a["start_bonus"] > 0)

	# --- Minispiel-Belohnung ---
	_check("Minispiele schütten Münzen aus", run_a["mg_coins"] > 0)
	_check("Bessere Punktzahl gibt nie weniger Münzen", run_a["reward_ok"])
	_check("Kein Minispiel zweimal hintereinander", run_a["no_repeat"])
	_check("Mehrere verschiedene Minispiele gespielt (%d)" % run_a["distinct"],
		run_a["distinct"] >= 3)

	# --- Balancing-Ziel: knappes Rennen ---
	_check("Mehr als ein Spieler hat am Ende Sterne (%d)" % run_a["star_holders"],
		run_a["star_holders"] >= 2)

	# --- Menschlicher Spieler über den Transport ---
	_test_human_flow()

	# --- Serverseitige Validierung (Anti-Cheat) ---
	_test_validation()
	_test_authoritative_scoring()

	print("")
	print("Endstand Lauf A (Seed %d):" % SEED_A)
	for line in run_a["standings"]:
		print("  " + line)

	print("")
	print("%d/%d Prüfungen bestanden." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


## Spielt eine reine KI-Partie durch (kein Mensch, alles vom Seed bestimmt).
func _run_ai_match(seed: int) -> Dictionary:
	var server := MatchServer.new()
	var defs: Array = []
	for i in PLAYERS:
		defs.append({"id": "p%d" % i, "name": "P%d" % i, "char": "", "ai": true})
	server.configure(defs, seed, TestMap.build_fields(), ROUNDS)

	var stats := _new_stats()
	server.event.connect(_collect.bind(stats))

	var transport := LocalTransport.new(server)
	transport.now_override = NOW
	transport.start()

	stats["ended"] = server.phase == MatchServer.Phase.ENDED
	stats["standings"] = _format_standings(server)
	return stats


## Spielt eine Partie mit einem menschlichen Spieler, der über den Transport
## würfelt und abgibt. Prüft, dass Roll- und Submit-Fluss durchlaufen.
func _test_human_flow() -> void:
	var server := MatchServer.new()
	var defs: Array = [{"id": "human", "name": "Mensch", "char": "", "ai": false}]
	for i in 3:
		defs.append({"id": "ai%d" % i, "name": "Bot%d" % i, "char": "", "ai": true})
	server.configure(defs, SEED_A, TestMap.build_fields(), ROUNDS)

	var mg_count := {"n": 0}
	server.event.connect(func(evt: Dictionary) -> void:
		if MatchProtocol.type_of(evt) == MatchProtocol.EV_MINIGAME_RESULT:
			mg_count["n"] += 1
	)

	var transport := LocalTransport.new(server)
	transport.now_override = NOW
	transport.start()

	# Der Mensch handelt, sobald er dran ist — vor jedem Timeout.
	var guard := 0
	while server.phase != MatchServer.Phase.ENDED and guard < 5000:
		guard += 1
		if server.phase == MatchServer.Phase.AWAIT_ROLL \
				and server.current_player == 0:
			transport.send_command(MatchProtocol.roll(&"human"))
		elif server.phase == MatchServer.Phase.MINIGAME \
				and not server._mg_have.get(0, false):
			# Eine gültige Abgabe für das GERADE laufende Minispiel — mit
			# der falschen ID würde der Server sie zu Recht verwerfen.
			var mg_id := StringName(server._mg_entry.get("id", ""))
			transport.send_command(MatchProtocol.submit(&"human", mg_id, [
				{"task": 0, "answer": 0, "time_ms": 500},
			]))
		transport.poll()

	_check("Menschlicher Spieler: Partie läuft bis zum Ende durch",
		server.phase == MatchServer.Phase.ENDED)
	_check("Menschlicher Spieler: alle Minispielrunden ausgewertet",
		mg_count["n"] == ROUNDS)


## Prüft die Plausibilitätsregeln für Abgaben.
func _test_validation() -> void:
	var max_ms := 60000
	_check("Validierung: gültige Abgabe akzeptiert",
		MatchServer.validate_submission([
			{"task": 0, "answer": 1, "time_ms": 800},
			{"task": 1, "answer": 2, "time_ms": 1600},
		], max_ms))
	_check("Validierung: zu schnelle Antwort abgelehnt",
		not MatchServer.validate_submission([
			{"task": 0, "answer": 1, "time_ms": 50},
		], max_ms))
	_check("Validierung: Antwort nach Ablauf abgelehnt",
		not MatchServer.validate_submission([
			{"task": 0, "answer": 1, "time_ms": max_ms + 500},
		], max_ms))
	_check("Validierung: nicht steigende Zeiten abgelehnt",
		not MatchServer.validate_submission([
			{"task": 0, "answer": 1, "time_ms": 1000},
			{"task": 1, "answer": 2, "time_ms": 900},
		], max_ms))


## Prüft, dass der Server die Punkte selbst nachrechnet.
func _test_authoritative_scoring() -> void:
	var entry := MinigameRegistry.by_id(&"rechnen_zielzahl")
	var scene: PackedScene = load(entry["scene"])
	var game = scene.instantiate()
	game.setup(12345)

	# Alle richtig gegen alle falsch — der Server muss den Unterschied sehen,
	# ohne der behaupteten Punktzahl zu trauen.
	var right: Array = []
	var wrong: Array = []
	for i in 5:
		var correct: int = game.tasks[i].correct
		right.append({"task": i, "answer": correct})
		wrong.append({"task": i, "answer": (correct + 1) % game.tasks[i].answer_count()})

	var score_right: int = game.authoritative_score(right)
	var score_wrong: int = game.authoritative_score(wrong)
	game.free()

	_check("Autoritative Wertung: richtige Antworten geben Punkte", score_right > 0)
	_check("Autoritative Wertung: falsche Antworten geben weniger",
		score_wrong < score_right)


# ---------------------------------------------------------------------------
# Event-Auswertung
# ---------------------------------------------------------------------------

func _new_stats() -> Dictionary:
	return {
		"stream": [],
		"turns": 0,
		"minigames": 0,
		"start_bonus": 0,
		"mg_coins": 0,
		"distinct": 0,
		"star_holders": 0,
		"dice_ok": true,
		"pos_ok": true,
		"coins_ok": true,
		"reward_ok": true,
		"no_repeat": true,
		"ended": false,
		"standings": [],
		"_seen_mg": [],
		"_field_count": TestMap.build_fields().size(),
	}


func _collect(evt: Dictionary, stats: Dictionary) -> void:
	# Der Event-Strom als serialisierte Liste — die Grundlage des
	# Determinismus-Vergleichs.
	stats["stream"].append(JSON.stringify(evt))

	match MatchProtocol.type_of(evt):
		MatchProtocol.EV_DICE_ROLLED:
			stats["turns"] += 1
			var v: int = evt["value"]
			if v < 1 or v > 6:
				stats["dice_ok"] = false
		MatchProtocol.EV_PLAYER_MOVED:
			var to: int = evt["to"]
			if to < 0 or to >= stats["_field_count"]:
				stats["pos_ok"] = false
		MatchProtocol.EV_FIELD_RESOLVED:
			if evt["coins"] < 0:
				stats["coins_ok"] = false
			if String(evt["msg"]).begins_with("Über Start"):
				stats["start_bonus"] += 1
		MatchProtocol.EV_MINIGAME_RESULT:
			stats["minigames"] += 1
			var seen: Array = stats["_seen_mg"]
			if not seen.is_empty() and seen[-1] == evt["mg"]:
				stats["no_repeat"] = false
			seen.append(evt["mg"])
			_check_rewards(evt, stats)
		MatchProtocol.EV_MATCH_ENDED:
			_finalize_stats(evt, stats)


func _check_rewards(evt: Dictionary, stats: Dictionary) -> void:
	var scores: Array = evt["scores"]
	var rewards: Array = evt["rewards"]
	for r in rewards:
		stats["mg_coins"] += r
		if r <= 0 or r > MatchServer.MINIGAME_REWARDS[0]:
			stats["reward_ok"] = false
	# Wer mehr Punkte hat, darf nicht weniger Münzen bekommen.
	for a in scores.size():
		for b in scores.size():
			if scores[a] > scores[b] and rewards[a] < rewards[b]:
				stats["reward_ok"] = false


func _finalize_stats(evt: Dictionary, stats: Dictionary) -> void:
	var distinct := {}
	for id in stats["_seen_mg"]:
		distinct[id] = true
	stats["distinct"] = distinct.size()

	var holders := 0
	for s in evt["standings"]:
		if s["stars"] > 0:
			holders += 1
	stats["star_holders"] = holders


func _format_standings(server: MatchServer) -> Array:
	var out: Array = []
	for s in server._standings():
		out.append("%s: %d Sterne, %d Münzen" % [s["name"], s["stars"], s["coins"]])
	return out


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  OK      %s" % label)
	else:
		_failures += 1
		print("  FEHLER  %s" % label)
