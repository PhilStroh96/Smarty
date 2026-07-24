extends NetTransport
class_name RelayTransport

## Der Transport eines [b]Gastes[/b] im host-autoritativen Online-Spiel.
##
## Ein Gast hat keinen eigenen Server. Er schickt seine Absichten (Commands)
## über das Relay an den Host, der den [MatchServer] betreibt, und bekommt
## dessen Events zurück. Aus Sicht des [MatchClient] ist das exakt derselbe
## [NetTransport] wie der [LocalTransport] — nur dass die Wahrheit auf einem
## anderen Gerät steht. Genau deshalb läuft der komplette Client unverändert,
## egal ob offline oder online (PLAN.md §2.1).

## Der Lobby-Stand hat sich geändert (Beitritt, Verlassen, Host-Wechsel).
signal lobby_updated(host_id: String, members: Array)

var endpoint: RelayEndpoint
var host_id: String = ""
var members: Array = []


func _init(p_endpoint: RelayEndpoint) -> void:
	endpoint = p_endpoint
	endpoint.received.connect(_on_msg)


## Tritt einem Raum bei. [param id] ist zugleich die eigene Spieler-ID.
func join(room: String, id: String, name: String) -> void:
	endpoint.send(RelayProtocol.hello(room, id, name))


func send_command(cmd: Dictionary) -> void:
	# Keine ID mitschicken — das Relay stempelt den authentifizierten
	# Absender. Was der Client behauptet, zählt nicht.
	endpoint.send(RelayProtocol.cmd(cmd))


func poll() -> void:
	endpoint.poll()


func close() -> void:
	endpoint.send(RelayProtocol.bye())
	# Signal trennen, sonst halten sich Endpoint und Transport gegenseitig
	# (RefCounted-Zyklus) und bleiben nach der Partie im Speicher.
	if endpoint.received.is_connected(_on_msg):
		endpoint.received.disconnect(_on_msg)
	endpoint.close()


func _on_msg(msg: Dictionary) -> void:
	match RelayProtocol.kind_of(msg):
		RelayProtocol.EVT:
			event_received.emit(msg.get("evt", {}))
		RelayProtocol.WELCOME, RelayProtocol.PRESENCE:
			host_id = msg.get("host", "")
			members = msg.get("members", [])
			lobby_updated.emit(host_id, members)
