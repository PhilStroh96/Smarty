class_name MatchClient
extends Node

## Die Client-Seite einer Partie.
##
## Der Client [b]berechnet nichts[/b] (PLAN.md §2.1). Er schickt Absichten an
## den Server (würfeln, Antworten abgeben) und spiegelt die zurückkommenden
## Events: Figuren bewegen, Stände übernehmen, Minispiele anzeigen. Was der
## Server sagt, gilt.
##
## Nach außen sendet er dieselben Signale wie früher der TurnManager, damit
## Szene und HUD unverändert daran hängen können. Der Unterschied steckt nur
## darunter: Die Wahrheit kommt jetzt vom [MatchServer] über einen
## [NetTransport], nicht aus lokaler Rechnung.
##
## [b]Event-Puffer:[/b] Der Server feuert Events, so schnell er rechnet — bei
## reinen KI-Zügen einen ganzen Schwung auf einmal. Der Client legt sie in
## eine Warteschlange und spielt sie in menschlichem Tempo ab. So bleibt die
## Darstellung ruhig, egal wie schnell der Server ist.

signal turn_started(player_index: int)
signal dice_rolled(player_index: int, value: int)
signal player_moved(player_index: int, field_index: int)
signal field_resolved(player_index: int, message: String)
signal round_started(round_index: int)
signal minigame_starting(entry: Dictionary)
signal minigame_finished(entry: Dictionary, scores: Array, rewards: Array)
signal match_finished

## Pause zwischen den Phasen eines Zugs, damit man folgen kann. Im Test 0.
var pace: float = 0.45

var transport: NetTransport
var board: BoardMap
var pawns: Array[Pawn] = []

## Die ID des Spielers an diesem Gerät. Nur für ihn wird der Würfelknopf
## freigegeben; für alle anderen läuft der Zug automatisch ab.
var local_player_id: StringName = &""

## Spielt ein Minispiel und liefert das [MinigameResult].
## Signatur: [code]func(entry: Dictionary, seed: int) -> MinigameResult[/code]
## Ohne diese Callable meldet der Client eine leere Abgabe (für Tests).
var minigame_runner: Callable

var _queue: Array[Dictionary] = []
var _roll_requested: bool = false
var _running: bool = false
## Wird true, sobald der Server den lokalen Spieler übernimmt (Timeout).
## Bricht den Wurf-Warteloop, damit die Wiedergabe nicht einfriert.
var _local_taken_over: bool = false


func setup(p_transport: NetTransport, p_board: BoardMap, p_pawns: Array[Pawn],
		p_local_id: StringName) -> void:
	transport = p_transport
	board = p_board
	pawns = p_pawns
	local_player_id = p_local_id
	transport.event_received.connect(_on_event)


## Startet die Partie und die Ereignis-Wiedergabe.
func begin() -> void:
	if _running:
		return
	_running = true
	_playback_loop()
	if transport is LocalTransport:
		(transport as LocalTransport).start()


func is_running() -> bool:
	return _running


## Vom HUD aufgerufen, wenn der lokale Spieler den Würfelknopf drückt.
func request_roll() -> void:
	_roll_requested = true


func _process(_delta: float) -> void:
	# Den Transport takten: bei LocalTransport treibt das den Server und
	# füllt die Warteschlange; Netz-Transporte empfangen von selbst.
	if transport != null:
		transport.poll()


func _on_event(evt: Dictionary) -> void:
	# Eine Übernahme des lokalen Spielers sofort erkennen (Peek), nicht erst
	# bei der Wiedergabe: Solange der Client im Wurf-Warteloop hängt, wird
	# die Queue nicht abgearbeitet — das Flag muss also schon beim Eingang
	# gesetzt werden, damit der Loop abbrechen kann.
	if MatchProtocol.type_of(evt) == MatchProtocol.EV_PLAYER_LEFT \
			and evt.get("id", "") == String(local_player_id):
		_local_taken_over = true
	_queue.append(evt)


## Spielt die Warteschlange in ruhigem Tempo ab.
func _playback_loop() -> void:
	while _running:
		if _queue.is_empty():
			await get_tree().process_frame
			continue
		await _handle(_queue.pop_front())


func _handle(evt: Dictionary) -> void:
	match MatchProtocol.type_of(evt):
		MatchProtocol.EV_TURN_STARTED:
			await _handle_turn(evt)
		MatchProtocol.EV_DICE_ROLLED:
			dice_rolled.emit(evt["player"], evt["value"])
			await _wait(pace)
		MatchProtocol.EV_PLAYER_MOVED:
			await _handle_move(evt)
		MatchProtocol.EV_FIELD_RESOLVED:
			_apply_totals(evt["player"], evt["coins"], evt["stars"])
			field_resolved.emit(evt["player"], evt["msg"])
			await _wait(pace)
		MatchProtocol.EV_MINIGAME_STARTING:
			await _handle_minigame(evt)
		MatchProtocol.EV_MINIGAME_RESULT:
			_handle_minigame_result(evt)
		MatchProtocol.EV_ROUND_ADVANCED:
			GameState.current_round = evt["round"]
			round_started.emit(evt["round"])
		MatchProtocol.EV_MATCH_ENDED:
			_running = false
			match_finished.emit()
		MatchProtocol.EV_PLAYER_LEFT:
			_mark_left(evt["id"])


func _handle_turn(evt: Dictionary) -> void:
	var idx: int = evt["player"]
	GameState.current_player_index = idx
	GameState.current_round = evt["round"]

	var p: PlayerInfo = GameState.players[idx]
	var is_local := p.id == local_player_id and not p.is_computer_controlled()

	# Einen alten Würfelwunsch VOR der Anzeige löschen, nicht danach. Sonst
	# geht ein Tap verloren, der fällt, während die "Du bist dran"-Anzeige
	# noch läuft — und ein stehengebliebener Wunsch aus der letzten Runde
	# würde fälschlich sofort würfeln.
	if is_local:
		_roll_requested = false

	turn_started.emit(idx)

	# Ist der lokale Spieler dran, auf den Würfelknopf warten und dann die
	# Absicht an den Server schicken. Für alle anderen tut der Client
	# nichts — der Server würfelt automatisch und schickt das Ergebnis.
	if is_local:
		while not _roll_requested and _running and not _local_taken_over:
			await get_tree().process_frame
		# Nur würfeln, wenn wirklich getippt wurde. Hat der Server in der
		# Zwischenzeit übernommen (Timeout), hat er schon gewürfelt — dann
		# nichts senden und die gestauten Übernahme-Events durchlaufen lassen.
		if _roll_requested and not _local_taken_over:
			transport.send_command(MatchProtocol.roll(local_player_id))
	else:
		await _wait(pace)


func _handle_move(evt: Dictionary) -> void:
	var idx: int = evt["player"]
	var steps: int = evt["steps"]
	var pawn := _pawn_for(idx)
	if pawn != null:
		await pawn.move_steps(steps)
	if idx < GameState.players.size():
		GameState.players[idx].board_position = evt["to"]
	player_moved.emit(idx, evt["to"])


func _handle_minigame(evt: Dictionary) -> void:
	var entry: Dictionary = evt["entry"]
	minigame_starting.emit(entry)

	# Nur der lokale Mensch spielt selbst; seine Antworten gehen an den
	# Server, der sie autoritativ auswertet. Fehlt ein Runner (Test), wird
	# eine leere Abgabe geschickt.
	var p := _local_player()
	if p != null and not p.is_computer_controlled() and minigame_runner.is_valid():
		var result: MinigameResult = await minigame_runner.call(entry, evt["seed"])
		var subs: Array = result.submissions if result != null else []
		transport.send_command(MatchProtocol.submit(local_player_id, entry["id"], subs))
	elif p != null and not p.is_computer_controlled():
		transport.send_command(MatchProtocol.submit(local_player_id, entry["id"], []))


func _handle_minigame_result(evt: Dictionary) -> void:
	var coins: Array = evt["coins"]
	var stars: Array = evt["stars"]
	var wins: Array = evt.get("wins", [])
	for i in GameState.players.size():
		if i < coins.size():
			GameState.players[i].coins = coins[i]
		if i < stars.size():
			GameState.players[i].stars = stars[i]
		if i < wins.size():
			GameState.players[i].minigames_won = wins[i]
	minigame_finished.emit(_entry_by_id(evt["mg"]), evt["scores"], evt["rewards"])


# ---------------------------------------------------------------------------
# Mirror-Hilfen
# ---------------------------------------------------------------------------

func _apply_totals(idx: int, coins: int, stars: int) -> void:
	if idx < GameState.players.size():
		GameState.players[idx].coins = coins
		GameState.players[idx].stars = stars


func _mark_left(player_id: String) -> void:
	for p in GameState.players:
		if String(p.id) == player_id:
			p.taken_over_by_ai = true
			return


func _local_player() -> PlayerInfo:
	for p in GameState.players:
		if p.id == local_player_id:
			return p
	return null


func _entry_by_id(id: String) -> Dictionary:
	return MinigameRegistry.by_id(StringName(id))


func _pawn_for(player_index: int) -> Pawn:
	if player_index < pawns.size():
		return pawns[player_index]
	return null


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
