class_name HostSession
extends Node

## Die Host-Seite einer Online-Partie, von der Lobby bis zum Spielstart.
##
## Auf dem Host-Gerät läuft der [MatchServer]. Diese Session hält ihn, die
## [RelayHostBridge] (zu den Gästen) und einen [LocalTransport] (für das eigene
## Spiel des Hosts) zusammen und überlebt den Szenenwechsel in die Brettphase —
## deshalb ein [Node], den der Aufrufer an die Wurzel hängt, nicht an die Szene.
##
## Ablauf: Session anlegen → Lobby zeigt Mitglieder → Host drückt Start →
## [method start_match] konfiguriert den Server aus den Mitgliedern und legt den
## Kontext für die Brettszene ab. Der eigentliche Serverstart passiert erst,
## wenn die Brettszene ihren Client startet (dann fließt MATCH_STARTED an alle).

signal lobby_updated(host_id: String, members: Array)

const ROUNDS := 12

var host_id: StringName
var server: MatchServer
var bridge: RelayHostBridge
var local_transport: LocalTransport

var _started := false


## [param endpoint] ist die Relay-Verbindung des Hosts (Loopback oder WebSocket).
func setup(endpoint: RelayEndpoint, p_host_id: StringName, host_name: String, code: String) -> void:
	host_id = p_host_id
	server = MatchServer.new()
	bridge = RelayHostBridge.new(server, endpoint)
	bridge.lobby_updated.connect(func(h: String, m: Array) -> void: lobby_updated.emit(h, m))
	local_transport = LocalTransport.new(server)
	local_transport.local_sender_id = String(host_id)
	bridge.join(code, String(host_id), host_name)


func _process(_delta: float) -> void:
	# Eingehende Gast-Commands lesen und den Server nach Zeit weitertreiben.
	# Läuft sowohl in der Lobby (Presence) als auch während der Partie
	# (Gast-Würfe/-Abgaben kommen über die Brücke, nicht über den eigenen
	# Client des Hosts).
	if bridge != null:
		bridge.poll()


func members() -> Array:
	return bridge.members if bridge != null else []


func can_start() -> bool:
	return not _started and members().size() >= 1


## Konfiguriert den Server aus den Lobby-Mitgliedern und legt den Kontext für
## die Brettszene ab. Startet den Server noch NICHT — das macht die Brettszene
## über den Client, damit kein Event verloren geht.
func start_match() -> void:
	if not can_start():
		return
	_started = true

	var defs: Array = []
	for m in members():
		defs.append({"id": m["id"], "name": m["name"], "char": "", "ai": false})

	var seed := int(Time.get_unix_time_from_system())
	server.configure(defs, seed, TestMap.build_fields(), ROUNDS)
	_build_host_mirror(defs, seed)

	# Der Host baut seinen Client selbst (über den LocalTransport) — kein
	# vorbereiteter Client nötig, weil der Start hier in seiner Hand liegt.
	MatchSetup.configure(local_transport, host_id, shutdown)


func _build_host_mirror(defs: Array, seed: int) -> void:
	var mirror: Array[PlayerInfo] = []
	for d in defs:
		var p := PlayerInfo.new(StringName(d["id"]), d["name"])
		p.is_ai = false
		mirror.append(p)
	GameState.start_match(GameState.Mode.ONLINE, mirror, seed, ROUNDS)


## Schließt alle Verbindungen. Wird beim Verlassen der Brettszene aufgerufen.
func shutdown() -> void:
	if bridge != null:
		bridge.close()
	if local_transport != null:
		local_transport.close()
	if is_inside_tree():
		queue_free()
