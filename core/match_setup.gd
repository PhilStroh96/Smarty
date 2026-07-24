class_name MatchSetup
extends RefCounted

## Übergabe an die nächste Brettszene.
##
## Godots Szenenwechsel reicht keine Daten weiter, deshalb legt der Aufrufer
## (Menü, Lobby, Session) den Kontext hier ab, bevor er zur Brettszene wechselt.
## Die Brettszene liest ihn beim Start aus und räumt ihn ab.
##
## Ist nichts gesetzt, baut die Brettszene eine lokale Solo-Partie gegen KI —
## so bleibt sie auch direkt startbar (Debug, Screenshot-Werkzeug).

## Der Transport der Partie ([LocalTransport] oder [RelayTransport]).
static var transport: NetTransport = null

## Die ID des Spielers an diesem Gerät.
static var local_id: StringName = &""

## Ein bereits aufgebauter Client (Gast-Fall). Er hört von Anfang an am
## Transport und puffert Events, während die Brettszene noch lädt. Leer, wenn
## die Brettszene ihren Client selbst baut (lokal, Host).
static var client: MatchClient = null

## Wird beim Verlassen der Brettszene aufgerufen, um Session-Ressourcen
## (Server, Brücke, Verbindungen) sauber zu schließen. Leer, wenn die
## Brettszene selbst aufräumt.
static var teardown: Callable = Callable()


static func is_set() -> bool:
	return transport != null


## Setzt den Kontext für die nächste Brettszene. [GameState] muss vorher
## bereits mit den Spielern befüllt sein.
static func configure(p_transport: NetTransport, p_local_id: StringName,
		p_teardown: Callable = Callable(), p_client: MatchClient = null) -> void:
	transport = p_transport
	local_id = p_local_id
	teardown = p_teardown
	client = p_client


static func clear() -> void:
	transport = null
	local_id = &""
	teardown = Callable()
	client = null
