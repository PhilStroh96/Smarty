extends Node

## Spielt eine komplette Partie als [b]Gast[/b] durch — voller Client-Stack
## ([MatchClient] + [RelayTransport]) über den [LoopbackHub] zu einem Host, der
## den [MatchServer] betreibt.
##
##     godot --headless --path . res://tests/relay_client_test.tscn
##
## Beweist, dass ein Gast online genauso spielt wie offline: Der Client ist
## transport-blind, also läuft er über das Relay unverändert bis zum Ende und
## sein gespiegelter Zustand deckt sich mit der Wahrheit des Servers.
##
## Aufbau: Host (p0) = KI, damit seine Züge der Server selbst erledigt.
## Gast (p1) = der getestete Mensch. p2, p3 = KI.

const SEED := 4242
const ROUNDS := 5
const LOCAL := &"p1"
const TIMEOUT_SEC := 20.0

var _server: MatchServer
var _bridge: RelayHostBridge
var _client: MatchClient
var _transport: RelayTransport
var _finished := false
var _elapsed := 0.0
var _done := false


func _ready() -> void:
	var hub := LoopbackHub.new()

	# Server auf dem Host-Gerät.
	_server = MatchServer.new()
	var defs: Array = [
		{"id": "p0", "name": "Host", "char": "", "ai": true},
		{"id": "p1", "name": "Gast", "char": "", "ai": false},
		{"id": "p2", "name": "Bot", "char": "", "ai": true},
		{"id": "p3", "name": "Bot", "char": "", "ai": true},
	]
	_server.configure(defs, SEED, TestMap.build_fields(), ROUNDS)
	var host_ep := hub.create_endpoint()
	_bridge = RelayHostBridge.new(_server, host_ep)
	_bridge.now_override = 0
	_bridge.join("ROOM", "p0", "Host")

	# Der Gast: eigener Spielerspiegel im GameState.
	var mirror: Array[PlayerInfo] = []
	for d in defs:
		var p := PlayerInfo.new(StringName(d["id"]), d["name"])
		p.is_ai = d["ai"]
		mirror.append(p)
	GameState.start_match(GameState.Mode.ONLINE, mirror, SEED, ROUNDS)

	var guest_ep := hub.create_endpoint()
	_transport = RelayTransport.new(guest_ep)
	_transport.join("ROOM", "p1", "Gast")

	var board := BoardMap.new()
	add_child(board)
	board.build(TestMap.build_fields())

	_client = MatchClient.new()
	add_child(_client)
	_client.pace = 0.0
	_client.setup(_transport, board, [], LOCAL)
	_client.minigame_runner = _fake_minigame
	_client.turn_started.connect(_on_turn)
	_client.match_finished.connect(func() -> void: _finished = true)
	_client.begin()

	_bridge.start_match()


func _on_turn(player_index: int) -> void:
	# Ist der Gast dran, sofort würfeln lassen.
	if GameState.players[player_index].id == LOCAL:
		_client.request_roll()


func _fake_minigame(_entry: Dictionary, _seed: int) -> MinigameResult:
	var r := MinigameResult.new()
	r.submissions.append({"task": 0, "answer": 0, "time_ms": 500})
	return r


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	# Den Server nach Zeit weitertreiben (KI-Züge, Timeouts). Die Züge des
	# Gastes lösen dessen Commands über das Relay aus.
	_bridge.pump()
	if _finished:
		_report(true)
	elif _elapsed > TIMEOUT_SEC:
		_report(false)


func _report(ok: bool) -> void:
	_done = true
	print("Relay-Gast-Test (Loopback)")
	print("")

	var mirror_ok := ok
	var detail := ""
	if ok:
		# Der gespiegelte Zustand des Gastes muss der Wahrheit des Servers
		# entsprechen — Münzen, Sterne, Position, gewonnene Minispiele.
		for i in _server.players.size():
			var s: PlayerInfo = _server.players[i]
			var c: PlayerInfo = GameState.players[i]
			if s.coins != c.coins or s.stars != c.stars \
					or s.board_position != c.board_position \
					or s.minigames_won != c.minigames_won:
				mirror_ok = false
				detail = "p%d: Server(%d M,%d S,Feld %d,%d Siege) vs Gast(%d,%d,%d,%d)" % [
					i, s.coins, s.stars, s.board_position, s.minigames_won,
					c.coins, c.stars, c.board_position, c.minigames_won]

	_out("Gast spielt über das Relay bis zum Ende durch", ok)
	_out("Gespiegelter Zustand deckt sich mit dem Server", mirror_ok)
	if detail != "":
		print("          " + detail)

	var fails := (0 if ok else 1) + (0 if mirror_ok else 1)

	# Verbindungen lösen, damit nichts leakt.
	if _transport != null:
		_transport.close()
	if _bridge != null:
		_bridge.close()

	print("")
	print("%d/2 Prüfungen bestanden." % (2 - fails))
	get_tree().quit(1 if fails > 0 else 0)


func _out(label: String, ok: bool) -> void:
	print("  %s  %s" % ["OK     " if ok else "FEHLER ", label])
