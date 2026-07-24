class_name LoopbackHub
extends RefCounted

## Ein Relay im selben Prozess — der Test-Zwilling des Cloudflare-Workers.
##
## Bildet dieselbe Weiterleitung nach, ohne Netzwerk: Räume, Mitglieder,
## Host-Bestimmung, Command-zum-Host, Event-an-alle. Damit lässt sich das
## komplette Online-Zusammenspiel (Host-Autorität, Command-Routing,
## Anti-Spoof) deterministisch und headless testen — genau wie [LocalTransport]
## den Server testbar macht. Der echte WebSocket-Weg ist danach nur noch ein
## dünner Austausch des Endpunkts.
##
## [b]Die Routing-Regeln hier sind die Referenz[/b]: Der Worker
## (server/relay-worker/) muss sich exakt gleich verhalten.

class Room extends RefCounted:
	var code: String
	var members: Array = []      # of Endpoint
	var host_id: String = ""


## Ein Endpunkt im Loopback. Stellt Nachrichten synchron zu — kein poll nötig.
class Endpoint extends RelayEndpoint:
	var _hub: LoopbackHub
	var _room: Room

	func _init(hub: LoopbackHub) -> void:
		_hub = hub

	func send(msg: Dictionary) -> void:
		_hub._on_message(self, msg)

	func close() -> void:
		_hub._on_message(self, RelayProtocol.bye())


var _rooms: Dictionary = {}


## Erzeugt einen neuen, noch nicht beigetretenen Endpunkt.
func create_endpoint() -> RelayEndpoint:
	return Endpoint.new(self)


func _on_message(ep: Endpoint, msg: Dictionary) -> void:
	match RelayProtocol.kind_of(msg):
		RelayProtocol.HELLO:
			_join(ep, msg)
		RelayProtocol.CMD:
			_route_cmd(ep, msg)
		RelayProtocol.EVT:
			_route_evt(ep, msg)
		RelayProtocol.BYE:
			_leave(ep)


func _join(ep: Endpoint, msg: Dictionary) -> void:
	var code: String = msg.get("room", "")
	ep.id = msg.get("id", "")
	ep.display_name = msg.get("name", "")

	var room: Room = _rooms.get(code)
	if room == null:
		room = Room.new()
		room.code = code
		_rooms[code] = room
	# Der Erste im Raum ist der Host — auf seinem Gerät läuft der MatchServer.
	if room.host_id == "":
		room.host_id = ep.id
	room.members.append(ep)
	ep._room = room

	ep.received.emit(RelayProtocol.welcome(ep.id, room.host_id, _member_list(room)))
	_broadcast_presence(room)


func _route_cmd(ep: Endpoint, msg: Dictionary) -> void:
	var room: Room = ep._room
	if room == null:
		return
	# Command an den Host zustellen — mit der AUTHENTIFIZIERTEN Absender-ID
	# aus der Verbindung, nicht aus dem Inhalt. Das ist der Anti-Spoof-Kern.
	var host := _host_ep(room)
	if host != null:
		host.received.emit(RelayProtocol.cmd_from(ep.id, msg.get("cmd", {})))


func _route_evt(ep: Endpoint, msg: Dictionary) -> void:
	var room: Room = ep._room
	if room == null:
		return
	# Nur der Host darf Events broadcasten. Ein Gast, der es versucht, wird
	# ignoriert.
	if ep.id != room.host_id:
		return
	for m in room.members:
		if m.id != ep.id:
			m.received.emit(RelayProtocol.evt(msg.get("evt", {})))


func _leave(ep: Endpoint) -> void:
	var room: Room = ep._room
	if room == null:
		return
	room.members.erase(ep)
	# Verlässt der Host, wandert die Rolle weiter — sonst bliebe der Raum
	# ohne autoritativen Server zurück.
	if ep.id == room.host_id and not room.members.is_empty():
		room.host_id = room.members[0].id
	ep._room = null
	if not room.members.is_empty():
		_broadcast_presence(room)


func _host_ep(room: Room) -> Endpoint:
	for m in room.members:
		if m.id == room.host_id:
			return m
	return null


func _member_list(room: Room) -> Array:
	var out: Array = []
	for m in room.members:
		out.append({"id": m.id, "name": m.display_name})
	return out


func _broadcast_presence(room: Room) -> void:
	var p := RelayProtocol.presence(room.host_id, _member_list(room))
	for m in room.members:
		m.received.emit(p)
