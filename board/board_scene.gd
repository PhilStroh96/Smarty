extends Node2D

## Die Brettphase — für lokale und Online-Partien gleichermaßen.
##
## Woher Server und Transport kommen, entscheidet [MatchSetup]:
## [br]• [b]Nichts gesetzt[/b] (Direktstart/Debug): baut eine lokale Solo-Partie
##   gegen KI selbst auf.
## [br]• [b]Kontext gesetzt[/b] (Menü/Lobby/Session): nutzt den übergebenen
##   Transport und ggf. einen vorbereiteten Client. [GameState] ist dann schon
##   befüllt.
##
## Der Client bleibt derselbe [MatchClient] wie eh und je — er ist
## transport-blind, also läuft die Szene über [LocalTransport] (offline/Host)
## und [RelayTransport] (Gast) ohne Unterschied.

const ROUNDS := 12
const TOTAL_PLAYERS := 4
const LOCAL_ID := &"p0"

var _board: BoardMap
var _hud: BoardHud
var _camera: BoardCamera
var _client: MatchClient
var _minigame_layer: CanvasLayer
var _pawns: Array[Pawn] = []

# --- Kontext ---
var _transport: NetTransport
var _local_id: StringName = LOCAL_ID
var _teardown: Callable = Callable()
var _own_transport := false   # nur lokal gebaute Transporte selbst schließen


func _ready() -> void:
	_resolve_context()
	_build_world()
	_connect_signals()
	_client.begin()


func _exit_tree() -> void:
	# Session-Ressourcen (Server, Brücke, Verbindungen) sauber schließen.
	if _teardown.is_valid():
		_teardown.call()
	elif _own_transport and _transport != null:
		_transport.close()


## Holt den Partie-Kontext aus [MatchSetup] oder baut eine lokale Partie.
func _resolve_context() -> void:
	if MatchSetup.is_set():
		_transport = MatchSetup.transport
		_local_id = MatchSetup.local_id
		_teardown = MatchSetup.teardown
		_client = MatchSetup.client   # kann null sein (Host/lokal bauen selbst)
		MatchSetup.clear()
	else:
		_build_local_context()


## Baut eine lokale Solo-Partie gegen KI — der Fall ohne Menü.
func _build_local_context() -> void:
	var names := ["Du", "Bot Anna", "Bot Ben", "Bot Cem"]
	var defs: Array = []
	var mirror: Array[PlayerInfo] = []
	for i in TOTAL_PLAYERS:
		var is_ai := i > 0
		defs.append({"id": "p%d" % i, "name": names[i], "char": "pawn%d" % i, "ai": is_ai})
		var p := PlayerInfo.new(StringName("p%d" % i), names[i])
		p.is_ai = is_ai
		p.character_id = StringName("pawn%d" % i)
		mirror.append(p)

	var seed := int(Time.get_unix_time_from_system())
	GameState.start_match(GameState.Mode.LOCAL, mirror, seed, ROUNDS)

	var server := MatchServer.new()
	server.configure(defs, seed, TestMap.build_fields(), ROUNDS)
	var transport := LocalTransport.new(server)
	transport.local_sender_id = String(LOCAL_ID)
	_transport = transport
	_local_id = LOCAL_ID
	_own_transport = true


func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#161a2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	bg_layer.add_child(bg)
	add_child(bg_layer)

	_board = BoardMap.new()
	add_child(_board)
	_board.build(TestMap.build_fields())

	# Figuren als Kinder der Karte, damit sie in dieselbe Y-Sortierung fallen.
	for i in GameState.players.size():
		var pawn := Pawn.new()
		_board.add_child(pawn)
		pawn.setup(i, _board, 0)
		_pawns.append(pawn)

	_camera = BoardCamera.new()
	add_child(_camera)
	_camera.frame_board.call_deferred(_board)

	_hud = BoardHud.new()
	add_child(_hud)

	_minigame_layer = CanvasLayer.new()
	_minigame_layer.layer = 20
	add_child(_minigame_layer)

	# Ein vorbereiteter Client (Gast) hört schon am Transport und hat Events
	# gepuffert — ihm nur noch Brett und Figuren geben. Sonst selbst bauen.
	if _client != null:
		_client.board = _board
		_client.pawns = _pawns
		if _client.get_parent() == null:
			add_child(_client)
	else:
		_client = MatchClient.new()
		add_child(_client)
		_client.setup(_transport, _board, _pawns, _local_id)
	_client.minigame_runner = _run_minigame


func _connect_signals() -> void:
	_hud.roll_pressed.connect(_client.request_roll)

	_client.turn_started.connect(func(i: int) -> void: _hud.set_turn(i))
	_client.dice_rolled.connect(func(_i: int, value: int) -> void: _hud.set_dice(value))
	_client.field_resolved.connect(func(_i: int, msg: String) -> void: _hud.set_message(msg))
	_client.round_started.connect(func(_r: int) -> void: _hud.refresh())
	_client.minigame_finished.connect(func(_e: Dictionary, _s: Array, rewards: Array) -> void:
		_hud.show_minigame_result(rewards)
	)
	_client.match_finished.connect(_hud.show_result)


## Spielt ein Minispiel für den lokalen Spieler und liefert das rohe Ergebnis.
## Der Client schickt daraus nur die Antworten an den Server.
func _run_minigame(entry: Dictionary, seed: int) -> MinigameResult:
	var runner := MinigameRunner.new()
	_minigame_layer.add_child(runner)
	_hud.visible = false

	var result: MinigameResult = await runner.run(entry, seed)

	runner.queue_free()
	_hud.visible = true
	return result
