extends Node

## Spielt eine komplette Partie durch den [MatchClient] — also über den
## echten animierten Weg, nicht nur über die Server-Logik.
##
##     godot --headless --path . res://tests/client_flow_test.tscn
##
## Exit-Code 0 = grün, 1 = Fehler.
##
## Der Client hat einen eigenen, heiklen Teil: eine asynchrone
## Ereignis-Warteschlange, die Server-Events in menschlichem Tempo abspielt
## und an den passenden Stellen auf Eingaben wartet. Ein Headless-Servertest
## deckt das nicht ab. Dieser Test fährt den ganzen Client-Fluss ab —
## würfeln, bewegen, Minispiel abgeben, nächste Runde — und stellt sicher,
## dass er bis [signal MatchClient.match_finished] durchläuft und nicht in
## der Wiedergabe hängen bleibt.

const SEED := 4242
const ROUNDS := 5           # kürzer als eine echte Partie, reicht zum Prüfen
const PLAYERS := 4
const LOCAL_ID := &"p0"
const TIMEOUT_SEC := 20.0

var _client: MatchClient
var _finished := false
var _turns_seen := 0
var _minigames_seen := 0
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
	var transport := LocalTransport.new(server)

	# Ein Brett ohne Grafik-Zwang: hinzufügen geht headless, Sprites
	# rendern nur nicht. Die Figuren lassen wir weg — dann bewegt der
	# Client sofort statt zu animieren, und der Test läuft schnell.
	var board := BoardMap.new()
	add_child(board)
	board.build(TestMap.build_fields())

	_client = MatchClient.new()
	add_child(_client)
	_client.pace = 0.0
	_client.setup(transport, board, [], LOCAL_ID)
	_client.minigame_runner = _fake_minigame

	_client.turn_started.connect(_on_turn)
	_client.minigame_finished.connect(func(_e, _s, _r) -> void: _minigames_seen += 1)
	_client.match_finished.connect(func() -> void: _finished = true)

	_client.begin()


func _on_turn(player_index: int) -> void:
	_turns_seen += 1
	# Ist der lokale Mensch dran, sofort würfeln lassen.
	if player_index == 0:
		_client.request_roll()


## Ein Minispiel-Ersatz: gibt sofort eine gültige Abgabe zurück, ohne etwas
## anzuzeigen. Der Client schickt sie an den Server.
func _fake_minigame(_entry: Dictionary, _seed: int) -> MinigameResult:
	var r := MinigameResult.new()
	r.submissions.append({"task": 0, "answer": 0, "time_ms": 500})
	return r


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
	print("Client-Fluss-Test")
	print("")
	var checks := 0
	var fails := 0

	var results := [
		["Partie läuft durch den Client bis zum Ende", ok],
		["Jede Runde hatte einen Zug je Spieler (%d)" % _turns_seen,
			_turns_seen == ROUNDS * PLAYERS],
		["Jede Runde hatte ein Minispiel (%d)" % _minigames_seen,
			_minigames_seen == ROUNDS],
	]
	for r in results:
		checks += 1
		if r[1]:
			print("  OK      %s" % r[0])
		else:
			fails += 1
			print("  FEHLER  %s" % r[0])

	print("")
	print("%d/%d Prüfungen bestanden." % [checks - fails, checks])
	get_tree().quit(1 if fails > 0 else 0)
