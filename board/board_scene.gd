extends Node2D

## Die Brettphase — setzt Karte, Figuren, Kamera, HUD und Rundenlogik
## zusammen und spielt eine Partie durch.
##
## Alles wird per Code aufgebaut statt in einer .tscn verdrahtet. Solange
## das hier Platzhalter sind, wäre eine Szenendatei nur eine zweite Stelle,
## an der dieselbe Struktur gepflegt werden muss.

const ROUNDS := 12
const HUMAN_PLAYERS := 1
const TOTAL_PLAYERS := 4
const LOCAL_ID := &"p0"

var _board: BoardMap
var _hud: BoardHud
var _camera: BoardCamera
var _client: MatchClient
var _server: MatchServer
var _transport: LocalTransport
var _minigame_layer: CanvasLayer
var _pawns: Array[Pawn] = []


func _ready() -> void:
	_setup_players()
	_build_world()
	_connect_signals()
	_client.begin()


func _exit_tree() -> void:
	# Den Server-Transport-Zyklus lösen, sonst bleibt eine ganze Partie
	# (Server, Transport, Client) nach dem Verlassen im Speicher.
	if _transport != null:
		_transport.close()


func _setup_players() -> void:
	var names := ["Du", "Bot Anna", "Bot Ben", "Bot Cem"]
	var player_defs: Array = []
	var mirror: Array[PlayerInfo] = []
	for i in TOTAL_PLAYERS:
		var is_ai := i >= HUMAN_PLAYERS
		player_defs.append({
			"id": "p%d" % i,
			"name": names[i],
			"char": "pawn%d" % i,
			"ai": is_ai,
		})
		# Der Client-Spiegel: dieselben Spieler als eigene Objekte. Der
		# Server bekommt seine eigene Kopie (in configure), damit Client
		# und Server nie dieselben Instanzen teilen.
		var p := PlayerInfo.new(StringName("p%d" % i), names[i])
		p.is_ai = is_ai
		p.character_id = StringName("pawn%d" % i)
		mirror.append(p)

	# Zufälliger Match-Seed. In der Online-Partie gibt ihn später der
	# Server vor — hier reicht die Uhrzeit.
	var seed := int(Time.get_unix_time_from_system())
	GameState.start_match(GameState.Mode.LOCAL, mirror, seed, ROUNDS)

	# Der autoritative Server im selben Prozess (LocalTransport).
	_server = MatchServer.new()
	_server.configure(player_defs, seed, TestMap.build_fields(), ROUNDS)
	_transport = LocalTransport.new(_server)
	# Alle Eingaben an diesem Gerät gelten als der lokale Spieler.
	_transport.local_sender_id = String(LOCAL_ID)


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

	# Figuren als Kinder der Karte, damit sie in dieselbe Y-Sortierung
	# fallen wie die Felder.
	for i in TOTAL_PLAYERS:
		var pawn := Pawn.new()
		_board.add_child(pawn)
		pawn.setup(i, _board, 0)
		_pawns.append(pawn)

	_camera = BoardCamera.new()
	add_child(_camera)
	# Die Testkarte passt komplett auf den Bildschirm — das ganze Feld zu
	# zeigen ist hier informativer, als einer Figur hinterherzufahren.
	_camera.frame_board.call_deferred(_board)

	_hud = BoardHud.new()
	add_child(_hud)

	# Eigene Ebene über dem Brett: Das Minispiel legt sich formatfüllend
	# darüber und darf das Brett-HUD nicht durchscheinen lassen.
	_minigame_layer = CanvasLayer.new()
	_minigame_layer.layer = 20
	add_child(_minigame_layer)

	_client = MatchClient.new()
	add_child(_client)
	_client.setup(_transport, _board, _pawns, LOCAL_ID)
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
##
## Der Client schickt daraus nur die Antworten an den Server — die Punkte
## rechnet der Server selbst nach. Der Rückgabewert ist deshalb das ganze
## [MinigameResult] (mit den Einzelantworten), nicht eine Punktzahl.
func _run_minigame(entry: Dictionary, seed: int) -> MinigameResult:
	var runner := MinigameRunner.new()
	_minigame_layer.add_child(runner)
	_hud.visible = false

	var result: MinigameResult = await runner.run(entry, seed)

	runner.queue_free()
	_hud.visible = true
	return result
