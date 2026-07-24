class_name RelayHostBridge
extends RefCounted

## Die Host-Seite des Online-Spiels: die Brücke zwischen Relay und Server.
##
## Auf dem Gerät des Hosts läuft der [MatchServer]. Diese Brücke verbindet ihn
## mit dem Relay:
## [br]• Jedes Server-Event geht als Broadcast an alle Gäste.
## [br]• Jeder Gast-Command wird dem Server zugeführt — mit der [b]vom Relay
##   authentifizierten[/b] Absender-ID, nicht der behaupteten. Damit kann kein
##   Gast im Namen eines anderen handeln (das Anti-Cheat-Versprechen aus M3
##   gilt auch über das Netz).
##
## Der Host spielt zusätzlich [i]selbst[/i]: dafür hängt auf demselben Gerät
## ein [LocalTransport] am selben Server (in-process). Seine eigenen Commands
## laufen also nicht übers Relay, seine Events sieht er direkt.
##
## [b]Host-Migration[/b] (Host verlässt mitten in der Partie) ist bewusst noch
## nicht gelöst — für Tests unter Freunden verkraftbar, siehe docs/netcode.md.

## Der Lobby-Stand hat sich geändert (Beitritt, Verlassen).
signal lobby_updated(host_id: String, members: Array)

var server: MatchServer
var endpoint: RelayEndpoint
var members: Array = []

## Im Test auf einen festen Wert setzen, um die Zeit zu steuern.
var now_override: int = -1


func _init(p_server: MatchServer, p_endpoint: RelayEndpoint) -> void:
	server = p_server
	endpoint = p_endpoint
	server.event.connect(_on_server_event)
	endpoint.received.connect(_on_relay_msg)


## Öffnet den Raum als Host. [param id] ist zugleich die Spieler-ID des Hosts.
func join(room: String, id: String, name: String) -> void:
	endpoint.send(RelayProtocol.hello(room, id, name))


## Startet die Partie und lässt den Server bis zum nächsten Wartepunkt laufen.
func start_match() -> void:
	server.start(_now())
	pump()


## Taktet den Server, bis er nichts mehr von allein tun kann (KI, Timeouts).
func pump() -> void:
	var guard := 0
	while server.poll(_now()):
		guard += 1
		if guard > 10000:
			push_error("RelayHostBridge.pump: Schleife bricht nicht ab")
			break


## Pro Frame aufrufen: eingehende Relay-Nachrichten abholen und den Server
## nach Zeit weitertreiben (KI-Züge, Timeouts).
func poll() -> void:
	endpoint.poll()
	pump()


## Trennt Server und Relay. Bricht die RefCounted-Zyklen, sonst bleiben
## Server, Brücke und Endpoint nach der Partie im Speicher.
func close() -> void:
	if server != null and server.event.is_connected(_on_server_event):
		server.event.disconnect(_on_server_event)
	if endpoint != null and endpoint.received.is_connected(_on_relay_msg):
		endpoint.received.disconnect(_on_relay_msg)
	if endpoint != null:
		endpoint.close()


func _on_server_event(evt: Dictionary) -> void:
	# Jedes Event an alle Gäste. (Der eigene Client des Hosts hängt separat
	# über einen LocalTransport am Server und braucht das Relay nicht.)
	endpoint.send(RelayProtocol.evt(evt))


func _on_relay_msg(msg: Dictionary) -> void:
	match RelayProtocol.kind_of(msg):
		RelayProtocol.CMD:
			# "from" ist die authentifizierte Absender-ID vom Relay.
			server.command(msg.get("cmd", {}), _now(), msg.get("from", ""))
			pump()
		RelayProtocol.WELCOME, RelayProtocol.PRESENCE:
			members = msg.get("members", [])
			lobby_updated.emit(msg.get("host", ""), members)


func _now() -> int:
	return now_override if now_override >= 0 else Time.get_ticks_msec()
