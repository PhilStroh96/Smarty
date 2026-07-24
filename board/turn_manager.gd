class_name TurnManager
extends Node

## Die Rundenlogik: wer ist dran, was würfelt er, was passiert danach.
##
## [b]Determinismus:[/b] Der Würfel zieht nicht aus einem fortlaufenden
## Generator, sondern aus einem pro Zug abgeleiteten Seed
## ([method SeededRng.fork]-Prinzip, PLAN.md §2.1). Folge: Der Wurf von
## Spieler 2 in Runde 5 ist immer derselbe — auch wenn sich vorher etwas
## an der Zuglogik ändert. Ohne das wäre eine Partie nicht reproduzierbar
## und der Server könnte Client-Meldungen nicht gegenprüfen.
##
## [b]Headless-fähig:[/b] Ohne zugewiesene [Pawn]s läuft die komplette
## Partie als reine Datenänderung durch, ohne Animation und ohne Grafik.
## Genau das nutzt tests/board_match_test.gd.

signal turn_started(player_index: int)
signal dice_rolled(player_index: int, value: int)
signal player_moved(player_index: int, field_index: int)
signal field_resolved(player_index: int, message: String)
signal round_started(round_index: int)
signal minigame_starting(entry: Dictionary)
signal minigame_finished(entry: Dictionary, scores: Array, rewards: Array)
signal match_finished

const DICE_MIN := 1
const DICE_MAX := 6

## Münzen nach Platzierung im Minispiel. Index = Platz.
##
## Der Abstand ist bewusst flach: Wer ein Minispiel verliert, soll
## Rückstand haben, aber nicht abgehängt sein. Party-Games leben davon,
## dass bis zum Schluss alle mitspielen (PLAN.md §1.3).
const MINIGAME_REWARDS := [10, 6, 3, 1]

## Wie viele zuletzt gespielte Minispiele gemieden werden.
const RECENT_MEMORY := 3

## Pause zwischen den Phasen eines Zugs, damit man folgen kann.
## In Tests auf 0 gesetzt.
var pace: float = 0.45

## Wenn true, würfelt der Manager selbst statt auf [method request_roll]
## zu warten. Für KI-Spieler und für Tests.
var auto_play: bool = false

var board: BoardMap
var pawns: Array[Pawn] = []

## Spielt ein Minispiel und liefert die Punktzahl des menschlichen Spielers.
##
## Signatur: [code]func(entry: Dictionary, seed: int) -> int[/code]
##
## Bleibt die Callable leer, würfelt der Manager auch für den Menschen ein
## Ergebnis aus. Genau das nutzt der Headless-Test: Die komplette Partie
## inklusive Minispielphasen läuft ohne Grafik und ohne Eingabe durch.
var minigame_runner: Callable

var _roll_requested: bool = false
var _running: bool = false
var _recent_minigames: Array = []


func setup(p_board: BoardMap, p_pawns: Array[Pawn] = []) -> void:
	board = p_board
	pawns = p_pawns


## Wird vom HUD aufgerufen, wenn der Spieler den Würfelknopf drückt.
func request_roll() -> void:
	_roll_requested = true


func is_running() -> bool:
	return _running


## Spielt die komplette Partie. Muss awaited werden.
func run_match() -> void:
	if _running:
		return
	_running = true

	while GameState.current_round < GameState.total_rounds:
		round_started.emit(GameState.current_round)
		for i in GameState.players.size():
			await _play_turn(i)
		await _play_minigame(GameState.current_round)
		GameState.advance_round()

	_running = false
	match_finished.emit()


## Die Minispielphase am Ende jeder Brettrunde.
##
## Hier kommt der Großteil der Münzen her — über das Brett allein wäre ein
## Stern kaum erreichbar.
func _play_minigame(round_index: int) -> void:
	var entry := MinigameRegistry.pick(GameState.match_seed, round_index, _recent_minigames)
	if entry.is_empty():
		return

	_recent_minigames.append(entry["id"])
	while _recent_minigames.size() > RECENT_MEMORY:
		_recent_minigames.pop_front()

	minigame_starting.emit(entry)

	var seed := SeededRng.mix(GameState.match_seed, 31337 + round_index)
	var scores: Array[int] = []
	for i in GameState.players.size():
		var player: PlayerInfo = GameState.players[i]
		if not player.is_computer_controlled() and minigame_runner.is_valid():
			scores.append(await minigame_runner.call(entry, seed))
		else:
			scores.append(simulate_score(seed, round_index, i))

	var rewards := _award_minigame(scores)
	minigame_finished.emit(entry, scores, rewards)


## Schätzt die Leistung eines KI-Spielers.
##
## Deterministisch aus dem Seed abgeleitet und bewusst breit gestreut: Bots,
## die immer gleich gut sind, machen die Minispielphase berechenbar und damit
## langweilig. Der Korridor entspricht grob dem, was ein Mensch in 60
## Sekunden schafft (rund 8-20 richtige Antworten).
static func simulate_score(seed: int, round_index: int, player_index: int) -> int:
	var r := SeededRng.new(SeededRng.mix(seed, round_index * 17 + player_index * 101))
	var correct := r.next_int(6, 21)
	var wrong := r.next_int(0, 4)
	return maxi(0, correct * 100 - wrong * 25)


## Verteilt Münzen nach Platzierung. Gibt die Belohnung je Spieler zurück.
func _award_minigame(scores: Array[int]) -> Array[int]:
	var order: Array[int] = []
	for i in scores.size():
		order.append(i)
	# Absteigend nach Punkten. Bei Gleichstand entscheidet der
	# Spielerindex — hässlich, aber vorhersagbar und damit prüfbar.
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
		for p in range(place, tie_end + 1):
			pot += MINIGAME_REWARDS[mini(p, MINIGAME_REWARDS.size() - 1)]
		var share := int(round(float(pot) / float(tie_end - place + 1)))

		for p in range(place, tie_end + 1):
			var pi := order[p]
			rewards[pi] = share
			GameState.players[pi].coins += share
			if p == 0:
				GameState.players[pi].minigames_won += 1

		place = tie_end + 1

	return rewards


func _play_turn(player_index: int) -> void:
	var player: PlayerInfo = GameState.players[player_index]
	GameState.current_player_index = player_index
	turn_started.emit(player_index)

	# Auf die Eingabe warten — außer bei KI oder im Testlauf.
	if not auto_play and not player.is_computer_controlled():
		_roll_requested = false
		while not _roll_requested:
			await get_tree().process_frame
		_roll_requested = false
	elif pace > 0.0:
		await _wait(pace)

	var value := roll_for(GameState.current_round, player_index)
	dice_rolled.emit(player_index, value)
	if pace > 0.0:
		await _wait(pace)

	var from_index := player.board_position
	var crossed_start := board.passed_start(from_index, value)

	# Mit Figur animiert laufen, ohne Figur direkt umsetzen.
	var pawn := _pawn_for(player_index)
	if pawn != null:
		player.board_position = await pawn.move_steps(value)
	else:
		player.board_position = board.wrap_index(from_index + value)

	player_moved.emit(player_index, player.board_position)

	# Startfeld-Prämie beim Überschreiten. Landet man exakt darauf,
	# zahlt der Feldeffekt selbst — sonst gäbe es doppelt.
	if crossed_start and player.board_position != 0:
		var bonus := TileTypes.coin_delta(TileTypes.Type.START)
		player.coins += bonus
		field_resolved.emit(player_index, "Über Start: +%d Münzen" % bonus)
		if pace > 0.0:
			await _wait(pace)

	_resolve_field(player_index)
	if pace > 0.0:
		await _wait(pace)


## Der Würfelwurf für eine bestimmte Runde und einen bestimmten Spieler.
##
## Reine Funktion: gleicher Match-Seed, gleiche Runde, gleicher Spieler
## ergibt immer denselben Wert — unabhängig davon, was sonst passiert ist.
static func roll_for(round_index: int, player_index: int) -> int:
	var seed := SeededRng.mix(GameState.match_seed, round_index * 100 + player_index)
	return SeededRng.new(seed).next_int(DICE_MIN, DICE_MAX)


func _resolve_field(player_index: int) -> void:
	var player: PlayerInfo = GameState.players[player_index]
	var field := board.get_field(player.board_position)
	if field == null:
		return

	if field.type == TileTypes.Type.STERN:
		if player.coins >= TileTypes.STAR_PRICE:
			player.coins -= TileTypes.STAR_PRICE
			player.stars += 1
			field_resolved.emit(player_index, "Stern gekauft! (-%d Münzen)" % TileTypes.STAR_PRICE)
		else:
			field_resolved.emit(player_index, "Zu wenig Münzen für einen Stern")
		return

	var delta := TileTypes.coin_delta(field.type)
	if delta == 0:
		field_resolved.emit(player_index, "")
		return

	# Münzen können nicht negativ werden — sonst kann ein Spieler in eine
	# Schuldenspirale geraten, aus der er nicht mehr herauskommt.
	player.coins = maxi(0, player.coins + delta)
	field_resolved.emit(player_index, TileTypes.label(field.type))


func _pawn_for(player_index: int) -> Pawn:
	if player_index < pawns.size():
		return pawns[player_index]
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
