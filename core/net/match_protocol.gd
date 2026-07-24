class_name MatchProtocol
extends RefCounted

## Die Nachrichten zwischen Client und Server.
##
## Zwei Richtungen, streng getrennt (PLAN.md §2.1):
## [br]• [b]Command[/b]: Client -> Server. Eine Absicht, kein Ergebnis. Der
##   Client [i]bittet[/i] zu würfeln; ob und was gewürfelt wird, entscheidet
##   allein der Server.
## [br]• [b]Event[/b]: Server -> alle Clients. Eine vollzogene Tatsache. Der
##   Client spiegelt sie nur noch, er berechnet nichts selbst.
##
## Alles hier ist als [Dictionary] aus einfachen Typen aufgebaut — Zahlen,
## Strings, Arrays. Kein Objekt, keine Referenz. Grund: Diese Nachrichten
## gehen später als JSON über Nakama. Was sich nicht in JSON abbilden lässt,
## darf hier nicht vorkommen.
##
## Der Schlüssel [code]"t"[/code] trägt in jeder Nachricht den Typ.

# --- Command-Typen (Client -> Server) ---
const CMD_JOIN := "join"          ## Der Lobby beitreten
const CMD_READY := "ready"        ## Bereit-Status umschalten
const CMD_START := "start"        ## Partie starten (nur Host)
const CMD_ROLL := "roll"          ## Würfeln, wenn man dran ist
const CMD_SUBMIT := "submit"      ## Minispiel-Antworten abgeben
const CMD_LEAVE := "leave"        ## Partie verlassen

# --- Event-Typen (Server -> Clients) ---
const EV_LOBBY := "lobby"              ## Lobby-Stand geändert
const EV_MATCH_STARTED := "match_started"
const EV_TURN_STARTED := "turn_started"
const EV_DICE_ROLLED := "dice_rolled"
const EV_PLAYER_MOVED := "player_moved"
const EV_FIELD_RESOLVED := "field_resolved"
const EV_MINIGAME_STARTING := "minigame_starting"
const EV_MINIGAME_RESULT := "minigame_result"
const EV_ROUND_ADVANCED := "round_advanced"
const EV_MATCH_ENDED := "match_ended"
const EV_PLAYER_LEFT := "player_left"
const EV_ERROR := "error"          ## Ein Command wurde abgelehnt


# ---------------------------------------------------------------------------
# Command-Bauer (Client-Seite)
# ---------------------------------------------------------------------------

static func join(player_id: StringName, name: String, character: StringName) -> Dictionary:
	return {"t": CMD_JOIN, "id": String(player_id), "name": name, "char": String(character)}


static func ready(player_id: StringName, is_ready: bool = true) -> Dictionary:
	return {"t": CMD_READY, "id": String(player_id), "ready": is_ready}


static func start(player_id: StringName) -> Dictionary:
	return {"t": CMD_START, "id": String(player_id)}


static func roll(player_id: StringName) -> Dictionary:
	return {"t": CMD_ROLL, "id": String(player_id)}


## [param submissions] ist die rohe Antwortliste des Minispiels:
## je Eintrag { "task": int, "answer": int, "time_ms": int }.
## Der Server rechnet die Punkte daraus selbst nach — der Client kann keine
## Punktzahl behaupten, nur seine Antworten melden.
static func submit(player_id: StringName, minigame_id: StringName, submissions: Array) -> Dictionary:
	return {
		"t": CMD_SUBMIT,
		"id": String(player_id),
		"mg": String(minigame_id),
		"subs": submissions,
	}


static func leave(player_id: StringName) -> Dictionary:
	return {"t": CMD_LEAVE, "id": String(player_id)}


# ---------------------------------------------------------------------------
# Event-Bauer (Server-Seite)
# ---------------------------------------------------------------------------

static func ev_lobby(code: String, players: Array, host_id: String, started: bool) -> Dictionary:
	return {"t": EV_LOBBY, "code": code, "players": players, "host": host_id, "started": started}


## [param players]: je Eintrag { "id": String, "name": String } — in der
## Reihenfolge, in der der Server konfiguriert wurde. Ein Gast baut daraus
## seinen Spielerspiegel auf, ohne die Presence-Liste getrennt abgleichen
## zu müssen.
static func ev_match_started(seed: int, rounds: int, players: Array) -> Dictionary:
	return {"t": EV_MATCH_STARTED, "seed": seed, "rounds": rounds, "players": players}


static func ev_turn_started(player_index: int, round_index: int, timeout_ms: int) -> Dictionary:
	# timeout_ms ist eine DAUER, keine absolute Uhrzeit. Absolute Deadlines
	# würden den Event-Strom an die Wanduhr binden und das Determinismus-
	# Versprechen brechen (zwei Server mit gleichem Seed, aber anderer
	# Startzeit lieferten verschiedene Events). Die Dauer ist konstant.
	return {"t": EV_TURN_STARTED, "player": player_index, "round": round_index, "timeout": timeout_ms}


static func ev_dice_rolled(player_index: int, value: int, auto: bool) -> Dictionary:
	# auto = true bedeutet: der Server hat für einen abwesenden Spieler
	# gewürfelt (KI-Übernahme). Der Client zeigt das anders an.
	return {"t": EV_DICE_ROLLED, "player": player_index, "value": value, "auto": auto}


static func ev_player_moved(player_index: int, from_field: int, to_field: int, steps: int) -> Dictionary:
	return {"t": EV_PLAYER_MOVED, "player": player_index, "from": from_field, "to": to_field, "steps": steps}


static func ev_field_resolved(player_index: int, message: String, coins: int, stars: int) -> Dictionary:
	# coins/stars sind die NEUEN Gesamtstände, nicht die Änderung — der
	# Client übernimmt sie direkt und muss nichts nachrechnen.
	return {"t": EV_FIELD_RESOLVED, "player": player_index, "msg": message, "coins": coins, "stars": stars}


static func ev_minigame_starting(entry: Dictionary, seed: int, timeout_ms: int) -> Dictionary:
	# Eine frische, JSON-reine Kopie des Registry-Eintrags — niemals die
	# Konstante selbst weiterreichen. Sonst teilen Event und Registry
	# dieselbe Referenz, und eine Mutation auf Client-Seite würde die
	# globale Registry auf allen Geräten verändern. StringName wird zu String.
	var clean := {
		"id": String(entry.get("id", "")),
		"title": entry.get("title", ""),
		"category": int(entry.get("category", 0)),
		"scene": entry.get("scene", ""),
	}
	return {"t": EV_MINIGAME_STARTING, "entry": clean, "seed": seed, "timeout": timeout_ms}


static func ev_minigame_result(entry_id: String, scores: Array, rewards: Array,
		coins: Array, stars: Array, wins: Array) -> Dictionary:
	return {
		"t": EV_MINIGAME_RESULT,
		"mg": entry_id,
		"scores": scores,
		"rewards": rewards,
		"coins": coins,   # neue Gesamt-Münzstände je Spieler
		"stars": stars,   # neue Gesamt-Sternstände je Spieler
		"wins": wins,     # neue Gesamt-Minispielsiege je Spieler
	}


static func ev_round_advanced(round_index: int) -> Dictionary:
	return {"t": EV_ROUND_ADVANCED, "round": round_index}


static func ev_match_ended(standings: Array) -> Dictionary:
	# standings: absteigend sortierte Liste { "id", "name", "stars", "coins" }
	return {"t": EV_MATCH_ENDED, "standings": standings}


static func ev_player_left(player_id: String, taken_over: bool) -> Dictionary:
	return {"t": EV_PLAYER_LEFT, "id": player_id, "ai": taken_over}


static func ev_error(reason: String) -> Dictionary:
	return {"t": EV_ERROR, "reason": reason}


## Der Typ einer beliebigen Nachricht, oder leerer String wenn keiner.
static func type_of(msg: Dictionary) -> String:
	return msg.get("t", "")
