class_name RelayProtocol
extends RefCounted

## Das Umschlag-Protokoll für das Relay (host-autoritatives Online-Spiel).
##
## Der Aufbau (docs/netcode.md): Ein Spieler (der Host) lässt den [MatchServer]
## auf seinem Gerät laufen. Das Relay — ein Cloudflare Durable Object oder im
## Test der [LoopbackHub] — ist nur ein dummer Weiterleiter. Es versteht das
## Spiel nicht; es kennt nur Räume, Mitglieder und diese wenigen Umschlag-Typen.
##
## Diese Nachrichten liegen [b]um[/b] die eigentlichen [MatchProtocol]-Commands
## und -Events herum. Beide Ebenen sind reines JSON, damit sie über WebSocket
## gehen können.
##
## [b]Wichtig fürs Anti-Cheat:[/b] Beim Weiterreichen eines Commands an den
## Host stempelt das Relay die [i]authentifizierte[/i] Absender-ID ([code]from[/code])
## aus der Verbindung — nicht aus dem Nachrichteninhalt. So kann ein Gast keinen
## Command im Namen eines anderen schicken.

const KEY := "k"  # Umschlag-Typ

# --- Client -> Relay ---
const HELLO := "hello"    ## Einem Raum beitreten { room, id, name }
const CMD := "cmd"        ## Ein Match-Command (Gast -> Host) { cmd }
const EVT := "evt"        ## Ein Match-Event (nur Host -> alle) { evt }
const BYE := "bye"        ## Raum verlassen

# --- Relay -> Client ---
const WELCOME := "welcome"    ## Antwort auf HELLO { id, host, members }
const PRESENCE := "presence"  ## Mitgliederstand geändert { host, members }
const ERROR := "err"          ## { reason }
# CMD und EVT gehen in beide Richtungen: der Host empfängt CMD (mit "from"),
# Gäste empfangen EVT.


# ---------------------------------------------------------------------------
# Bauer
# ---------------------------------------------------------------------------

static func hello(room: String, id: String, name: String) -> Dictionary:
	return {KEY: HELLO, "room": room, "id": id, "name": name}


## Ein Gast schickt einen Match-Command. Keine ID nötig — das Relay stempelt
## den authentifizierten Absender selbst.
static func cmd(match_command: Dictionary) -> Dictionary:
	return {KEY: CMD, "cmd": match_command}


## Der Host schickt ein Match-Event zum Broadcast an alle Gäste.
static func evt(match_event: Dictionary) -> Dictionary:
	return {KEY: EVT, "evt": match_event}


static func bye() -> Dictionary:
	return {KEY: BYE}


static func welcome(own_id: String, host_id: String, members: Array) -> Dictionary:
	return {KEY: WELCOME, "id": own_id, "host": host_id, "members": members}


static func presence(host_id: String, members: Array) -> Dictionary:
	return {KEY: PRESENCE, "host": host_id, "members": members}


## Ein an den Host zugestellter Command, mit authentifiziertem Absender.
static func cmd_from(sender_id: String, match_command: Dictionary) -> Dictionary:
	return {KEY: CMD, "from": sender_id, "cmd": match_command}


static func error(reason: String) -> Dictionary:
	return {KEY: ERROR, "reason": reason}


static func kind_of(msg: Dictionary) -> String:
	return msg.get(KEY, "")
