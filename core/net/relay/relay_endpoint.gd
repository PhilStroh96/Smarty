class_name RelayEndpoint
extends RefCounted

## Eine Verbindung zum Relay — die Sicht eines einzelnen Teilnehmers.
##
## Abstrahiert, wie Nachrichten hin- und hergehen, damit dieselbe Client-Logik
## über zwei Wege läuft:
## [br]• [LoopbackEndpoint] — im selben Prozess, für Tests.
## [br]• [WebSocketEndpoint] — echte Verbindung zum Cloudflare-Worker.
##
## [RelayTransport] (Gast) und [RelayHostBridge] (Host) kennen nur dieses
## Interface, nicht den Transportweg.

## Eine Nachricht ist eingetroffen.
signal received(msg: Dictionary)

## Die eigene Teilnehmer-ID (= die Spieler-ID in der Partie).
var id: String = ""

## Anzeigename.
var display_name: String = ""


## Schickt eine Nachricht ans Relay.
func send(_msg: Dictionary) -> void:
	push_error("RelayEndpoint.send nicht implementiert")


## Pumpt eingehende Nachrichten. Bei WebSocket pro Frame aufzurufen;
## der Loopback stellt sofort zu und braucht es nicht.
func poll() -> void:
	pass


func close() -> void:
	pass
