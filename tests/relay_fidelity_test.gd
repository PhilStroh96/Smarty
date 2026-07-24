extends Node

## Prüft die Relay-Weiterleitung über den [LoopbackHub] — ohne Netzwerk.
##
##     godot --headless --path . res://tests/relay_fidelity_test.tscn
##
## Zwei Eigenschaften, auf denen das Online-Spiel steht:
## [br]1. [b]Treue[/b]: Jeder Gast bekommt exakt denselben Event-Strom, den der
##    Server des Hosts erzeugt — gleiche Events, gleiche Reihenfolge.
## [br]2. [b]Anti-Spoof[/b]: Ein Gast kann keinen Command im Namen eines anderen
##    schicken. Das Relay stempelt den echten Absender.

const SEED := 4242
const ROUNDS := 6
const NOW := 0

var _failures := 0
var _checks := 0
var _cleanup: Array = []


func _ready() -> void:
	print("Relay-Treue-Test (Loopback)")
	print("")
	_test_fidelity()
	_test_antispoof()
	# Verbindungen lösen, damit die RefCounted-Zyklen brechen und beim Beenden
	# keine Objekte leaken — das prüft zugleich, dass close() wirklich greift.
	for obj in _cleanup:
		obj.close()
	print("")
	print("%d/%d Prüfungen bestanden." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


## Alle Spieler KI: der Host startet, die ganze Partie läuft durch, und beide
## Gäste müssen denselben Event-Strom sehen wie der Server.
func _test_fidelity() -> void:
	var hub := LoopbackHub.new()
	var server := MatchServer.new()
	var defs: Array = []
	for i in 4:
		defs.append({"id": "p%d" % i, "name": "P%d" % i, "char": "", "ai": true})
	server.configure(defs, SEED, TestMap.build_fields(), ROUNDS)

	# Referenz: der Event-Strom direkt am Server.
	var server_stream: Array = []
	server.event.connect(func(e: Dictionary) -> void:
		server_stream.append(JSON.stringify(e)))

	# Host (p0) betreibt den Server über die Brücke.
	var host_ep := hub.create_endpoint()
	var bridge := RelayHostBridge.new(server, host_ep)
	bridge.now_override = NOW
	bridge.join("ROOM", "p0", "P0")
	_cleanup.append(bridge)

	# Zwei Gäste sammeln, was bei ihnen ankommt.
	var g1_stream := _attach_guest(hub, "p1", "P1")
	var g2_stream := _attach_guest(hub, "p2", "P2")

	bridge.start_match()

	_check("Server hat Events erzeugt", server_stream.size() > 0)
	_check("Gast 1 sieht denselben Event-Strom wie der Server",
		g1_stream["events"] == server_stream)
	_check("Gast 2 sieht denselben Event-Strom wie der Server",
		g2_stream["events"] == server_stream)


## Ein Gast versucht, im Namen des Hosts zu würfeln. Das Relay stempelt seinen
## echten Absender, der Server lehnt ab, und der Zug des Hosts bleibt offen.
func _test_antispoof() -> void:
	var hub := LoopbackHub.new()
	var server := MatchServer.new()
	var defs: Array = [
		{"id": "p0", "name": "Host", "char": "", "ai": false},   # Host, am Zug
		{"id": "p1", "name": "Gast", "char": "", "ai": false},
		{"id": "p2", "name": "Bot", "char": "", "ai": true},
		{"id": "p3", "name": "Bot", "char": "", "ai": true},
	]
	server.configure(defs, SEED, TestMap.build_fields(), ROUNDS)

	var host_ep := hub.create_endpoint()
	var bridge := RelayHostBridge.new(server, host_ep)
	bridge.now_override = NOW
	bridge.join("ROOM", "p0", "Host")
	_cleanup.append(bridge)

	var guest_ep := hub.create_endpoint()
	var guest := RelayTransport.new(guest_ep)
	guest.join("ROOM", "p1", "Gast")
	_cleanup.append(guest)

	bridge.start_match()
	# Der Server wartet jetzt auf den Wurf von p0 (dem Host).
	_check("Vor Spoofing: Host ist am Zug", server.current_player == 0
		and server.phase == MatchServer.Phase.AWAIT_ROLL)

	# Gast p1 schickt einen Wurf, der VORGIBT von p0 zu sein.
	guest.send_command(MatchProtocol.roll(&"p0"))
	bridge.pump()

	# Das Relay hat "from=p1" gestempelt, der Server hat p1 != p0 erkannt.
	# Der Zug des Hosts ist unverändert offen.
	_check("Nach Spoofing: Host immer noch am Zug (Wurf abgelehnt)",
		server.current_player == 0 and server.phase == MatchServer.Phase.AWAIT_ROLL)

	# Zum Gegencheck: der Host würfelt selbst (in-process), dann geht es weiter.
	server.command(MatchProtocol.roll(&"p0"), NOW, "p0")
	bridge.pump()
	_check("Echter Wurf des Hosts wird angenommen", server.current_player != 0
		or server.phase != MatchServer.Phase.AWAIT_ROLL)


func _attach_guest(hub: LoopbackHub, id: String, name: String) -> Dictionary:
	var ep := hub.create_endpoint()
	var transport := RelayTransport.new(ep)
	var box := {"events": []}
	transport.event_received.connect(func(e: Dictionary) -> void:
		box["events"].append(JSON.stringify(e)))
	transport.join("ROOM", id, name)
	# Referenz auf den Transport halten, damit er nicht weggeräumt wird.
	box["_t"] = transport
	_cleanup.append(transport)
	return box


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  OK      %s" % label)
	else:
		_failures += 1
		print("  FEHLER  %s" % label)
