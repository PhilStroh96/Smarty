extends Node

## Prüft, dass der [MatchClient] NICHT einfriert, wenn der Server den lokalen
## Spieler per Timeout übernimmt.
##
##     godot --headless --path . res://tests/client_takeover_test.tscn
##
## Regression zu einem bestätigten Bug: Der Wurf-Warteloop brach nur bei
## einem Tap oder Spielende ab. Tippte der Spieler nie und übernahm der
## Server nach Timeout, staute sich die Ereignis-Warteschlange und
## match_finished kam nie. Dieser Test tippt bewusst NIE und spult die Zeit
## über den Timeout, um die Übernahme zu erzwingen.

const SEED := 4242
const ROUNDS := 3
const PLAYERS := 4
const LOCAL_ID := &"p0"
const TIMEOUT_SEC := 20.0
## Deutlich über TURN_TIMEOUT_MS (30000), damit der Server sofort übernimmt.
const JUMP_MS := 40000

var _client: MatchClient
var _transport: LocalTransport
var _finished := false
var _elapsed := 0.0
var _done := false


func _ready() -> void:
	var defs: Array = []
	var mirror: Array[PlayerInfo] = []
	for i in PLAYERS:
		var is_ai := i != 0
		defs.append({"id": "p%d" % i, "name": "P%d" % i, "char": "", "ai": is_ai})
		var p := PlayerInfo.new(StringName("p%d" % i), "P%d" % i)
		p.is_ai = is_ai
		mirror.append(p)
	GameState.start_match(GameState.Mode.LOCAL, mirror, SEED, ROUNDS)

	var server := MatchServer.new()
	server.configure(defs, SEED, TestMap.build_fields(), ROUNDS)
	_transport = LocalTransport.new(server)
	# Feste Startuhr, damit wir den Timeout gezielt auslösen können.
	_transport.now_override = 0

	var board := BoardMap.new()
	add_child(board)
	board.build(TestMap.build_fields())

	_client = MatchClient.new()
	add_child(_client)
	_client.pace = 0.0
	_client.setup(_transport, board, [], LOCAL_ID)
	# KEIN minigame_runner, KEIN request_roll: der lokale Spieler tut nichts.

	_client.turn_started.connect(_on_turn)
	_client.match_finished.connect(func() -> void: _finished = true)

	_client.begin()


func _on_turn(player_index: int) -> void:
	# Ist der lokale Spieler dran, die Uhr über den Timeout spulen — dann
	# übernimmt der Server beim nächsten poll. Der Spieler tippt NIE.
	if player_index == 0:
		_transport.now_override = JUMP_MS


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _finished:
		_report(true)
	elif _elapsed > TIMEOUT_SEC:
		_report(false)


func _report(ok: bool) -> void:
	_done = true
	print("Client-Übernahme-Test")
	print("")
	if ok:
		print("  OK      Client friert bei Server-Übernahme nicht ein, Partie endet")
	else:
		print("  FEHLER  Client hängt: match_finished kam nicht (Deadlock)")
	print("")
	print("%d/1 Prüfungen bestanden." % (1 if ok else 0))
	get_tree().quit(0 if ok else 1)
