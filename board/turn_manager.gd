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
signal match_finished

const DICE_MIN := 1
const DICE_MAX := 6

## Pause zwischen den Phasen eines Zugs, damit man folgen kann.
## In Tests auf 0 gesetzt.
var pace: float = 0.45

## Wenn true, würfelt der Manager selbst statt auf [method request_roll]
## zu warten. Für KI-Spieler und für Tests.
var auto_play: bool = false

var board: BoardMap
var pawns: Array[Pawn] = []

var _roll_requested: bool = false
var _running: bool = false


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
		GameState.advance_round()

	_running = false
	match_finished.emit()


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
