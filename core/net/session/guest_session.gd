class_name GuestSession
extends Node

## Die Gast-Seite einer Online-Partie, von der Lobby bis zum Spielstart.
##
## Ein Gast hat keinen Server. Diese Session hält seinen [RelayTransport] und
## einen [MatchClient], der [b]von Anfang an[/b] am Transport lauscht und Events
## puffert — auch schon, während die Brettszene noch lädt. So geht kein Event
## zwischen MATCH_STARTED und dem Szenenstart verloren.
##
## Der Knackpunkt (bisher ungetestet, jetzt abgedeckt): Der Gast kennt die
## Spielerliste erst mit MATCH_STARTED. Daraus baut er seinen [GameState]-
## Spiegel auf — Reihenfolge und Namen kommen aus dem Event — und übergibt den
## fertigen Client an die Brettszene.

signal lobby_updated(host_id: String, members: Array)
signal match_ready

var guest_id: StringName
var transport: RelayTransport
var client: MatchClient

var _ready_emitted := false


func setup(endpoint: RelayEndpoint, p_guest_id: StringName, guest_name: String, room: String) -> void:
	guest_id = p_guest_id
	transport = RelayTransport.new(endpoint)
	transport.lobby_updated.connect(func(h: String, m: Array) -> void: lobby_updated.emit(h, m))
	# Selbst auf MATCH_STARTED lauschen, um den Spielerspiegel zu bauen.
	transport.event_received.connect(_on_event)

	# Client jetzt schon anlegen, damit er Events puffert. Brett und Figuren
	# bekommt er erst von der Brettszene; bis dahin spielt er nichts ab.
	client = MatchClient.new()
	add_child(client)
	client.setup(transport, null, [], guest_id)

	transport.join(room, String(guest_id), guest_name)


func _on_event(evt: Dictionary) -> void:
	if _ready_emitted:
		return
	if MatchProtocol.type_of(evt) != MatchProtocol.EV_MATCH_STARTED:
		return
	_ready_emitted = true
	_build_guest_mirror(evt)
	# Den bereits puffernden Client an die Brettszene übergeben.
	MatchSetup.configure(transport, guest_id, shutdown, client)
	match_ready.emit()


func _build_guest_mirror(evt: Dictionary) -> void:
	var seed: int = evt.get("seed", 0)
	var rounds: int = evt.get("rounds", 12)
	var mirror: Array[PlayerInfo] = []
	for pinfo in evt.get("players", []):
		var p := PlayerInfo.new(StringName(pinfo.get("id", "")), pinfo.get("name", ""))
		p.is_ai = false
		mirror.append(p)
	GameState.start_match(GameState.Mode.ONLINE, mirror, seed, rounds)


func shutdown() -> void:
	if transport != null:
		transport.close()
	if is_inside_tree():
		queue_free()
