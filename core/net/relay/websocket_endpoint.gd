class_name WebSocketEndpoint
extends RelayEndpoint

## Ein Relay-Endpunkt über eine echte WebSocket-Verbindung (Cloudflare-Worker).
##
## Dasselbe Interface wie der [LoopbackHub]-Endpunkt — nur dass die Nachrichten
## übers Netz gehen. Weil die Routing-Logik im [LoopbackHub] headless getestet
## ist und der Worker sich exakt gleich verhält, ist dieser Endpunkt nur noch
## dünnes Rohr: JSON rein, JSON raus.
##
## [b]Noch nicht end-to-end getestet[/b] — das braucht einen deployten Worker
## und echte Geräte (siehe server/relay-worker/README.md). Die Nachrichten-
## Logik ist über den Loopback abgesichert.
##
## [codeblock]
## var ep := WebSocketEndpoint.new("wss://xy.workers.dev", "K7QM", "p0", "Anna")
## ep.connect_to_relay()
## # ep pro Frame pollen (macht der Transport/die Brücke bereits)
## [/codeblock]

## Verbindungszustand hat sich geändert.
signal state_changed(open: bool)
signal connect_failed(reason: String)

var _ws := WebSocketPeer.new()
var _url: String
var _hello: Dictionary
var _was_open := false
var _outbox: Array[Dictionary] = []


func _init(base_url: String, room: String, p_id: String, p_name: String) -> void:
	id = p_id
	display_name = p_name
	# Der Raum steckt im Pfad (bestimmt die Durable-Object-Instanz), id/name
	# gehen zusätzlich in der Hello-Nachricht mit.
	_url = "%s/room/%s" % [base_url.rstrip("/"), room]
	_hello = RelayProtocol.hello(room, p_id, p_name)


## Baut die Verbindung auf. Danach pro Frame [method poll] aufrufen.
func connect_to_relay() -> void:
	var err := _ws.connect_to_url(_url)
	if err != OK:
		connect_failed.emit("connect_to_url fehlgeschlagen: %d" % err)


func send(msg: Dictionary) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))
	else:
		# Vor dem Verbindungsaufbau puffern und nach dem Öffnen nachsenden.
		_outbox.append(msg)


func poll() -> void:
	_ws.poll()
	var state := _ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			# Beim Öffnen zuerst Hello, dann Gepuffertes.
			_ws.send_text(JSON.stringify(_hello))
			for m in _outbox:
				_ws.send_text(JSON.stringify(m))
			_outbox.clear()
			state_changed.emit(true)
		while _ws.get_available_packet_count() > 0:
			var text := _ws.get_packet().get_string_from_utf8()
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				received.emit(parsed)

	elif state == WebSocketPeer.STATE_CLOSED:
		if _was_open:
			_was_open = false
			state_changed.emit(false)


func close() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(RelayProtocol.bye()))
	_ws.close()
