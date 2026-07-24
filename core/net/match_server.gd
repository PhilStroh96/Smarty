class_name MatchServer
extends RefCounted

## Die einzige Wahrheit einer Partie (PLAN.md §2.1).
##
## Der Server verarbeitet [b]Commands[/b] (Absichten der Clients) und gibt
## [b]Events[/b] (vollzogene Tatsachen) aus. Clients spiegeln die Events
## nur — sie berechnen nichts selbst und können nichts erzwingen. Ein Client
## kann würfeln [i]wollen[/i]; ob und was fällt, entscheidet der Server aus
## dem Seed.
##
## [b]Headless und rein:[/b] Keine Szene, keine Grafik, kein Node. Alles hier
## hängt nur am Seed und an den eingehenden Commands, nie an der Uhrzeit.
## Zeit steuert ausschließlich Timeouts (wann die KI für einen abwesenden
## Spieler übernimmt) — und Timeouts ändern kein Ergebnis, nur den Zeitpunkt.
## Deshalb ist eine Partie bit-genau reproduzierbar.
##
## [b]Der spätere Nakama-Match-Handler:[/b] [method command] entspricht dem
## Empfang einer Nachricht, [method poll] dem match_loop-Tick. Die Portierung
## nach Nakama tauscht nur den Transport aus, nicht diese Logik.

## Ein Event ist entstanden und geht an alle Clients.
signal event(evt: Dictionary)

enum Phase { LOBBY, AWAIT_ROLL, MINIGAME, ENDED }

const DICE_MIN := 1
const DICE_MAX := 6

## Münzen nach Platzierung im Minispiel. Index = Platz.
## Flacher Abstand, damit Verlierer Rückstand haben, aber nicht abgehängt
## sind — Party-Games leben davon, dass bis zuletzt alle mitspielen.
const MINIGAME_REWARDS := [10, 6, 3, 1]

## Wie viele zuletzt gespielte Minispiele gemieden werden.
const RECENT_MEMORY := 3

## Zeit bis die KI für einen menschlichen Spieler übernimmt (ms).
## Bei mobilen Spielern ist Verbindungsverlust der Normalfall (PLAN.md §4.2).
const TURN_TIMEOUT_MS := 30000

## Zeit bis eine ausstehende Minispiel-Abgabe als aufgegeben gilt (ms).
const MINIGAME_TIMEOUT_MS := 90000

## Menschliche Reaktionszeit als Untergrenze für Antwortzeiten (ms).
const MIN_HUMAN_REACTION_MS := 150

var phase: Phase = Phase.LOBBY
var players: Array[PlayerInfo] = []
var seed: int = 0
var total_rounds: int = 12
var current_round: int = 0
var current_player: int = 0

var board: BoardData

var _recent: Array = []
var _deadline_ms: int = 0
var _mg_entry: Dictionary = {}
var _mg_seed: int = 0
var _mg_have: Dictionary = {}   # player_index -> bool (Abgabe eingegangen)
var _mg_scores: Dictionary = {} # player_index -> int (bereits gewertet)


# ---------------------------------------------------------------------------
# Aufbau
# ---------------------------------------------------------------------------

## Richtet eine Partie ein. [param player_defs]: je Eintrag
## { "id": String, "name": String, "char": String, "ai": bool }.
func configure(player_defs: Array, p_seed: int, field_defs: Array, rounds: int = 12) -> void:
	players.clear()
	for d in player_defs:
		var p := PlayerInfo.new(StringName(d.get("id", "")), d.get("name", ""))
		p.character_id = StringName(d.get("char", ""))
		p.is_ai = d.get("ai", false)
		players.append(p)
	seed = p_seed
	total_rounds = rounds
	board = BoardData.new(field_defs)
	current_round = 0
	current_player = 0
	phase = Phase.LOBBY
	_recent.clear()


## Startet die eigentliche Partie. [param now_ms] ist die aktuelle Zeit.
func start(now_ms: int) -> void:
	if phase != Phase.LOBBY:
		return
	# Der autoritative Kern verlässt sich nicht auf den Aufrufer: ohne
	# Spieler gäbe es sonst einen Out-of-bounds-Zugriff in _begin_turn.
	if players.is_empty():
		push_error("MatchServer.start ohne Spieler")
		return
	event.emit(MatchProtocol.ev_match_started(seed, total_rounds, _player_infos()))
	current_round = 0
	current_player = 0
	_begin_turn(now_ms)


# ---------------------------------------------------------------------------
# Eingang: Commands und Zeittakt
# ---------------------------------------------------------------------------

## Verarbeitet einen Command eines Clients.
##
## [param sender] ist die [b]authentifizierte[/b] Absender-ID, die der
## Transport liefert (bei Nakama die Presence-UserId). Ist sie gesetzt, gilt
## sie — die im Command behauptete ID wird ignoriert. So kann niemand im
## Namen eines anderen würfeln oder abgeben. Nur der [LocalTransport] auf
## einem vertrauten Einzelgerät darf [param sender] leer lassen; dann wird
## der behaupteten ID vertraut.
func command(cmd: Dictionary, now_ms: int, sender: String = "") -> void:
	var actor := sender if sender != "" else String(cmd.get("id", ""))
	match MatchProtocol.type_of(cmd):
		MatchProtocol.CMD_ROLL:
			_on_roll(actor, now_ms)
		MatchProtocol.CMD_SUBMIT:
			_on_submit(actor, cmd, now_ms)
		MatchProtocol.CMD_LEAVE:
			_on_leave(actor, now_ms)


## Der Zeittakt. Treibt alles voran, was keine menschliche Eingabe braucht:
## KI-Züge und Timeouts. Gibt true zurück, wenn etwas geschah — der Aufrufer
## kann in einer Schleife pollen, bis nichts mehr passiert.
func poll(now_ms: int) -> bool:
	match phase:
		Phase.AWAIT_ROLL:
			if now_ms >= _deadline_ms:
				# Deadline erreicht: KI-Spieler ziehen sofort, ein
				# abwesender Mensch wird von der KI übernommen.
				var p := players[current_player]
				if not p.is_ai and not p.taken_over_by_ai:
					p.taken_over_by_ai = true
					event.emit(MatchProtocol.ev_player_left(String(p.id), true))
				_do_roll(now_ms, true)
				return true
		Phase.MINIGAME:
			if now_ms >= _deadline_ms:
				_finalize_minigame(now_ms)
				return true
	return false


# ---------------------------------------------------------------------------
# Zug-Ablauf
# ---------------------------------------------------------------------------

func _begin_turn(now_ms: int) -> void:
	phase = Phase.AWAIT_ROLL
	var p := players[current_player]
	# Automatische Spieler (KI oder abwesend) würfeln beim nächsten poll
	# sofort; ein anwesender Mensch bekommt Bedenkzeit bis zum Timeout.
	if p.is_computer_controlled():
		_deadline_ms = now_ms
	else:
		_deadline_ms = now_ms + TURN_TIMEOUT_MS
	# Das Event trägt die Timeout-DAUER, nicht die absolute Deadline —
	# damit bleibt der Event-Strom unabhängig von der Wanduhr.
	event.emit(MatchProtocol.ev_turn_started(current_player, current_round, TURN_TIMEOUT_MS))


func _on_roll(actor: String, now_ms: int) -> void:
	if phase != Phase.AWAIT_ROLL:
		return
	# Nur der Spieler, der dran ist, darf würfeln — geprüft gegen die
	# authentifizierte Absender-ID, nicht gegen eine behauptete.
	if actor != String(players[current_player].id):
		event.emit(MatchProtocol.ev_error("Nicht am Zug"))
		return
	_do_roll(now_ms, false)


func _do_roll(now_ms: int, auto: bool) -> void:
	var idx := current_player
	var p := players[idx]
	var value := roll_for(seed, current_round, idx)
	event.emit(MatchProtocol.ev_dice_rolled(idx, value, auto))

	var from_index := p.board_position
	var crossed_start := board.passed_start(from_index, value)
	var to_index := board.wrap_index(from_index + value)
	p.board_position = to_index
	event.emit(MatchProtocol.ev_player_moved(idx, from_index, to_index, value))

	# Startfeld-Prämie beim Überschreiten. Landet man exakt darauf, zahlt
	# der Feldeffekt selbst — sonst gäbe es doppelt.
	if crossed_start and to_index != 0:
		p.coins += TileTypes.coin_delta(TileTypes.Type.START)
		event.emit(MatchProtocol.ev_field_resolved(
			idx, "Über Start: +%d Münzen" % TileTypes.coin_delta(TileTypes.Type.START),
			p.coins, p.stars))

	_resolve_field(idx)
	_advance_turn(now_ms)


func _resolve_field(idx: int) -> void:
	var p := players[idx]
	var t: TileTypes.Type = board.field_type(p.board_position)

	if t == TileTypes.Type.STERN:
		if p.coins >= TileTypes.STAR_PRICE:
			p.coins -= TileTypes.STAR_PRICE
			p.stars += 1
			event.emit(MatchProtocol.ev_field_resolved(
				idx, "Stern gekauft! (-%d Münzen)" % TileTypes.STAR_PRICE, p.coins, p.stars))
		else:
			event.emit(MatchProtocol.ev_field_resolved(
				idx, "Zu wenig Münzen für einen Stern", p.coins, p.stars))
		return

	var delta := TileTypes.coin_delta(t)
	# Münzen können nicht negativ werden — sonst gerät ein Spieler in eine
	# Schuldenspirale, aus der er nicht mehr herauskommt.
	p.coins = maxi(0, p.coins + delta)
	event.emit(MatchProtocol.ev_field_resolved(idx, TileTypes.label(t), p.coins, p.stars))


func _advance_turn(now_ms: int) -> void:
	current_player += 1
	if current_player < players.size():
		_begin_turn(now_ms)
	else:
		current_player = 0
		_begin_minigame(now_ms)


# ---------------------------------------------------------------------------
# Minispiel-Phase
# ---------------------------------------------------------------------------

func _begin_minigame(now_ms: int) -> void:
	var entry := MinigameRegistry.pick(seed, current_round, _recent)
	if entry.is_empty():
		_finish_round(now_ms)
		return

	_recent.append(entry["id"])
	while _recent.size() > RECENT_MEMORY:
		_recent.pop_front()

	phase = Phase.MINIGAME
	_mg_entry = entry
	_mg_seed = SeededRng.mix(seed, 31337 + current_round)
	_mg_have.clear()
	_mg_scores.clear()
	_deadline_ms = now_ms + MINIGAME_TIMEOUT_MS
	event.emit(MatchProtocol.ev_minigame_starting(entry, _mg_seed, MINIGAME_TIMEOUT_MS))

	# Sind gar keine anwesenden Menschen dabei, gibt es nichts abzuwarten.
	if not _has_pending_humans():
		_finalize_minigame(now_ms)


func _on_submit(actor: String, cmd: Dictionary, now_ms: int) -> void:
	if phase != Phase.MINIGAME:
		return
	if cmd.get("mg", "") != String(_mg_entry.get("id", "")):
		return  # Abgabe für ein anderes Minispiel — verspätet, verwerfen.

	# Die Abgabe zählt für den authentifizierten Absender, nicht für die im
	# Command genannte ID. Sonst könnte man eine leere Abgabe für ein Opfer
	# schicken und dessen echte, gute Abgabe damit blockieren.
	var idx := _index_of(actor)
	if idx < 0 or _mg_have.get(idx, false):
		return

	_mg_have[idx] = true
	_mg_scores[idx] = _score_submission(cmd.get("subs", []))

	# Sobald alle anwesenden Menschen abgegeben haben, sofort auswerten —
	# niemand soll unnötig auf den Timeout warten.
	if not _has_pending_humans():
		_finalize_minigame(now_ms)


## Bewertet eine Abgabe autoritativ: Erst Plausibilität (Zeiten), dann die
## Punkte aus den rohen Antworten nachrechnen. Scheitert die Prüfung, gibt
## es 0 Punkte statt der behaupteten — Betrug lohnt sich nicht.
func _score_submission(subs: Array) -> int:
	var scene: PackedScene = load(_mg_entry.get("scene", ""))
	if scene == null:
		return 0
	var game = scene.instantiate()
	var result := 0
	if game is QuizMinigame:
		game.setup(_mg_seed)
		var max_ms := int(game.duration_sec * 1000.0)
		if MatchServer.validate_submission(subs, max_ms):
			result = game.authoritative_score(subs)
		# ungültig -> 0 (kein Reward für unmögliche Zeiten)
	game.free()
	return result


func _finalize_minigame(now_ms: int) -> void:
	var scores: Array[int] = []
	for i in players.size():
		if _mg_scores.has(i):
			scores.append(_mg_scores[i])
		else:
			# Nicht abgegeben (KI oder abwesend): Leistung schätzen.
			scores.append(simulate_score(_mg_seed, current_round, i))

	var rewards := _award_minigame(scores)

	var coins: Array[int] = []
	var stars: Array[int] = []
	var wins: Array[int] = []
	for p in players:
		coins.append(p.coins)
		stars.append(p.stars)
		wins.append(p.minigames_won)

	event.emit(MatchProtocol.ev_minigame_result(
		String(_mg_entry.get("id", "")), scores, rewards, coins, stars, wins))
	_finish_round(now_ms)


func _finish_round(now_ms: int) -> void:
	current_round += 1
	event.emit(MatchProtocol.ev_round_advanced(current_round))
	if current_round >= total_rounds:
		phase = Phase.ENDED
		event.emit(MatchProtocol.ev_match_ended(_standings()))
	else:
		current_player = 0
		_begin_turn(now_ms)


# ---------------------------------------------------------------------------
# Verlassen
# ---------------------------------------------------------------------------

func _on_leave(actor: String, now_ms: int) -> void:
	# Vor dem Start oder nach dem Ende gibt es nichts zu verlassen — sonst
	# feuerte der Server ein Streu-Event in einen Zustand, in dem der Client
	# noch beendeten Spielerzustand ändern würde.
	if phase == Phase.ENDED or phase == Phase.LOBBY:
		return
	var idx := _index_of(actor)
	if idx < 0:
		return
	var p := players[idx]
	if not p.taken_over_by_ai:
		p.taken_over_by_ai = true
		event.emit(MatchProtocol.ev_player_left(String(p.id), true))

	# Verlässt der Spieler, der gerade dran ist, sofort für ihn ziehen.
	if phase == Phase.AWAIT_ROLL and idx == current_player:
		_do_roll(now_ms, true)
	# Verlässt im Minispiel der letzte anwesende Mensch, sofort auswerten —
	# sonst stockt die Partie bis zum Timeout, obwohl niemand mehr wartet.
	elif phase == Phase.MINIGAME and not _has_pending_humans():
		_finalize_minigame(now_ms)


# ---------------------------------------------------------------------------
# Reine Wertungsfunktionen (deterministisch, testbar)
# ---------------------------------------------------------------------------

## Der Würfelwurf für Seed, Runde und Spieler. Reine Funktion.
static func roll_for(match_seed: int, round_index: int, player_index: int) -> int:
	var s := SeededRng.mix(match_seed, round_index * 100 + player_index)
	return SeededRng.new(s).next_int(DICE_MIN, DICE_MAX)


## Schätzt die Minispiel-Leistung eines KI- oder abwesenden Spielers.
## Deterministisch und breit gestreut, damit die Phase nicht berechenbar wird.
static func simulate_score(mg_seed: int, round_index: int, player_index: int) -> int:
	var r := SeededRng.new(SeededRng.mix(mg_seed, round_index * 17 + player_index * 101))
	var correct := r.next_int(6, 21)
	var wrong := r.next_int(0, 4)
	return maxi(0, correct * MinigameBase.CORRECT_POINTS + wrong * MinigameBase.WRONG_POINTS)


## Plausibilitätsprüfung einer Abgabe. Reine Funktion.
##
## Wehrt die Punktzahl-Inflation ab: Keine Antwort darf schneller als die
## menschliche Reaktionszeit sein, keine nach Ablauf des Timers; zwischen
## zwei Antworten muss mindestens eine Reaktionszeit liegen (sonst könnte
## man tausende Antworten in Millisekundenschritten stapeln); und kein
## Aufgabenindex darf doppelt vorkommen (jede Aufgabe wird genau einmal
## beantwortet). Die eigentliche Punktdeckelung leistet zusätzlich
## [method QuizMinigame.authoritative_score], das Duplikate ignoriert.
static func validate_submission(subs: Array, max_duration_ms: int) -> bool:
	var last := -1
	var seen := {}
	for s in subs:
		var t: int = s.get("time_ms", -1)
		var task: int = s.get("task", -1)
		if t < MIN_HUMAN_REACTION_MS or t > max_duration_ms:
			return false
		if t - last < MIN_HUMAN_REACTION_MS:
			return false
		if seen.has(task):
			return false
		seen[task] = true
		last = t
	return true


## Verteilt Münzen nach Platzierung und schreibt sie den Spielern gut.
func _award_minigame(scores: Array[int]) -> Array[int]:
	var order: Array[int] = []
	for i in scores.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if scores[a] != scores[b]:
			return scores[a] > scores[b]
		return a < b
	)

	var rewards: Array[int] = []
	rewards.resize(scores.size())
	rewards.fill(0)

	var place := 0
	while place < order.size():
		# Gleichstand: Alle Betroffenen bekommen den Schnitt der belegten
		# Plätze, sonst wäre der Spielerindex bares Geld wert.
		var tie_end := place
		while tie_end + 1 < order.size() and scores[order[tie_end + 1]] == scores[order[place]]:
			tie_end += 1

		var pot := 0
		for pl in range(place, tie_end + 1):
			pot += MINIGAME_REWARDS[mini(pl, MINIGAME_REWARDS.size() - 1)]
		# Kaufmännische Rundung in reiner Integer-Arithmetik: (pot + n/2) / n.
		# Bewusst nicht round(float): das würde bei einer Portierung nach Go
		# oder JS (Banker's Rounding) andere Münzen vergeben.
		var n := tie_end - place + 1
		var share := (pot + n / 2) / n

		for pl in range(place, tie_end + 1):
			var pi := order[pl]
			rewards[pi] = share
			players[pi].coins += share
			if pl == 0:
				players[pi].minigames_won += 1

		place = tie_end + 1

	return rewards


# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------

func _has_pending_humans() -> bool:
	for i in players.size():
		var p := players[i]
		if not p.is_computer_controlled() and not _mg_have.get(i, false):
			return true
	return false


func _index_of(id: String) -> int:
	for i in players.size():
		if String(players[i].id) == id:
			return i
	return -1


func _player_infos() -> Array:
	var out: Array = []
	for p in players:
		out.append({"id": String(p.id), "name": p.display_name})
	return out


func _standings() -> Array:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: PlayerInfo, b: PlayerInfo) -> bool:
		if a.stars != b.stars:
			return a.stars > b.stars
		if a.coins != b.coins:
			return a.coins > b.coins
		# Stabiler Tie-Break über die ID: sonst wäre die Reihenfolge bei
		# vollständigem Gleichstand unbestimmt und ein portierter Server
		# lieferte ein anderes Endergebnis.
		return String(a.id) < String(b.id)
	)
	var out: Array = []
	for p in sorted:
		out.append({"id": String(p.id), "name": p.display_name, "stars": p.stars, "coins": p.coins})
	return out
