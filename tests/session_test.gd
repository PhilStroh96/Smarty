extends Node

## Prüft die Session-Schicht (Lobby -> Partie) über den [LoopbackHub].
##
##     godot --headless --path . res://tests/session_test.tscn
##
## Zwei Teile:
## [br]A. [HostSession] konfiguriert den Server aus den Lobby-Mitgliedern und
##    verschickt MATCH_STARTED mit der richtigen Spielerliste.
## [br]B. [GuestSession] baut aus MATCH_STARTED seinen [GameState]-Spiegel auf
##    (die bisher ungetestete Lücke) und spielt über den vorbereiteten Client
##    bis zum Ende — der Endzustand deckt sich mit dem Server.

const TIMEOUT_SEC := 20.0

var _failures := 0
var _checks := 0

# --- Teil B (asynchron) ---
var _b_server: MatchServer
var _b_bridge: RelayHostBridge
var _b_guest: GuestSession
var _b_client: MatchClient
var _b_finished := false
var _b_running := false
var _elapsed := 0.0
var _done := false


func _ready() -> void:
	print("Session-Test (Loopback)")
	print("")
	_test_host_session()
	_start_guest_session()


# ---------------------------------------------------------------------------
# Teil A — HostSession
# ---------------------------------------------------------------------------

func _test_host_session() -> void:
	var hub := LoopbackHub.new()

	var host := HostSession.new()
	add_child(host)
	host.setup(hub.create_endpoint(), &"h", "Host", "ROOM")

	# Ein Gast tritt bei (nur als Mitglied, ohne eigene Session).
	var guest_view := RelayTransport.new(hub.create_endpoint())
	var got_started := {"players": []}
	guest_view.event_received.connect(func(e: Dictionary) -> void:
		if MatchProtocol.type_of(e) == MatchProtocol.EV_MATCH_STARTED:
			got_started["players"] = e.get("players", []))
	guest_view.join("ROOM", "g", "Gast")

	_check("HostSession: Lobby zeigt beide Mitglieder", host.members().size() == 2)
	_check("HostSession: kann starten", host.can_start())

	host.start_match()
	_check("HostSession: Server mit 2 Spielern konfiguriert",
		host.server.players.size() == 2)
	_check("HostSession: Host-Spiegel im GameState gebaut",
		GameState.players.size() == 2 and GameState.mode == GameState.Mode.ONLINE)
	_check("HostSession: Kontext für die Brettszene gesetzt", MatchSetup.is_set())

	# Die Brettszene würde jetzt den Client starten; das simulieren wir.
	host.local_transport.start()
	_check("HostSession: MATCH_STARTED trägt die Spielerliste (mit Namen)",
		got_started["players"].size() == 2
		and got_started["players"][0].get("name", "") == "Host")

	# Aufräumen, damit Teil B einen sauberen GameState/MatchSetup hat.
	host.shutdown()
	guest_view.close()
	MatchSetup.clear()


# ---------------------------------------------------------------------------
# Teil B — GuestSession spielt eine ganze Partie
# ---------------------------------------------------------------------------

func _start_guest_session() -> void:
	var hub := LoopbackHub.new()

	# Roh-Host: Server + Brücke, ohne eigenen GameState (der gehört dem Gast).
	_b_server = MatchServer.new()
	var defs: Array = [
		{"id": "p0", "name": "Host", "char": "", "ai": true},
		{"id": "p1", "name": "Gast", "char": "", "ai": false},
		{"id": "p2", "name": "Bot", "char": "", "ai": true},
		{"id": "p3", "name": "Bot", "char": "", "ai": true},
	]
	_b_server.configure(defs, 4242, TestMap.build_fields(), 5)
	_b_bridge = RelayHostBridge.new(_b_server, hub.create_endpoint())
	_b_bridge.now_override = 0
	_b_bridge.join("ROOM", "p0", "Host")

	# Der Gast über seine Session.
	_b_guest = GuestSession.new()
	add_child(_b_guest)
	_b_guest.match_ready.connect(_on_guest_ready)
	_b_guest.setup(hub.create_endpoint(), &"p1", "Gast", "ROOM")

	# Server starten (das würde beim Host die Brettszene tun).
	_b_bridge.start_match()


func _on_guest_ready() -> void:
	# Die Brettszene würde dem vorbereiteten Client Brett und Figuren geben
	# und ihn starten — das simulieren wir headless.
	_check("GuestSession: GameState aus MATCH_STARTED gebaut (4 Spieler)",
		GameState.players.size() == 4)
	_check("GuestSession: Spielernamen korrekt übernommen",
		GameState.players.size() == 4 and GameState.players[1].display_name == "Gast")

	_b_client = MatchSetup.client
	MatchSetup.clear()
	var board := BoardMap.new()
	add_child(board)
	board.build(TestMap.build_fields())
	_b_client.board = board
	_b_client.pace = 0.0
	_b_client.minigame_runner = _fake_minigame
	_b_client.turn_started.connect(_on_guest_turn)
	_b_client.match_finished.connect(func() -> void: _b_finished = true)
	_b_client.begin()
	_b_running = true


func _on_guest_turn(player_index: int) -> void:
	if GameState.players[player_index].id == &"p1":
		_b_client.request_roll()


func _fake_minigame(_entry: Dictionary, _seed: int) -> MinigameResult:
	var r := MinigameResult.new()
	r.submissions.append({"task": 0, "answer": 0, "time_ms": 500})
	return r


func _process(delta: float) -> void:
	if _done or not _b_running:
		return
	_elapsed += delta
	_b_bridge.pump()   # KI-Züge und Timeouts vorantreiben
	if _b_finished:
		_finish()
	elif _elapsed > TIMEOUT_SEC:
		_check("GuestSession: Partie läuft bis zum Ende durch", false)
		_finish()


func _finish() -> void:
	if _b_finished:
		_check("GuestSession: Partie läuft bis zum Ende durch", true)
		var ok := true
		for i in _b_server.players.size():
			var s: PlayerInfo = _b_server.players[i]
			var c: PlayerInfo = GameState.players[i]
			if s.coins != c.coins or s.stars != c.stars \
					or s.board_position != c.board_position:
				ok = false
		_check("GuestSession: Endzustand deckt sich mit dem Server", ok)

	_b_guest.shutdown()
	_b_bridge.close()
	_done = true

	print("")
	print("%d/%d Prüfungen bestanden." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  OK      %s" % label)
	else:
		_failures += 1
		print("  FEHLER  %s" % label)
