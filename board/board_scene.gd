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

var _board: BoardMap
var _hud: BoardHud
var _camera: BoardCamera
var _turns: TurnManager
var _pawns: Array[Pawn] = []


func _ready() -> void:
	_setup_players()
	_build_world()
	_connect_signals()
	_turns.run_match()


func _setup_players() -> void:
	var names := ["Du", "Bot Anna", "Bot Ben", "Bot Cem"]
	var players: Array[PlayerInfo] = []
	for i in TOTAL_PLAYERS:
		var p := PlayerInfo.new(StringName("p%d" % i), names[i])
		p.is_ai = i >= HUMAN_PLAYERS
		p.character_id = StringName("pawn%d" % i)
		players.append(p)

	# Zufälliger Match-Seed. In der Online-Partie gibt ihn später der
	# Server vor — hier reicht die Uhrzeit.
	var seed := int(Time.get_unix_time_from_system())
	GameState.start_match(GameState.Mode.LOCAL, players, seed, ROUNDS)


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

	_turns = TurnManager.new()
	add_child(_turns)
	_turns.setup(_board, _pawns)


func _connect_signals() -> void:
	_hud.roll_pressed.connect(_turns.request_roll)

	_turns.turn_started.connect(func(i: int) -> void: _hud.set_turn(i))
	_turns.dice_rolled.connect(func(_i: int, value: int) -> void: _hud.set_dice(value))
	_turns.field_resolved.connect(func(_i: int, msg: String) -> void: _hud.set_message(msg))
	_turns.round_started.connect(func(_r: int) -> void: _hud.refresh())
	_turns.match_finished.connect(_hud.show_result)
