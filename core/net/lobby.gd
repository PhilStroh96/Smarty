class_name Lobby
extends RefCounted

## Der Warteraum vor der Partie (PLAN.md §4.1).
##
## Reine Zustandsmaschine, ohne Netz und ohne Grafik — dieselbe Logik läuft
## später auf dem Server und lässt sich hier vollständig testen. Wer den Code
## kennt, tritt bei; ist die Runde voll oder schon gestartet, wird abgewiesen.

## Der Lobby-Stand hat sich geändert (Beitritt, Bereit, Verlassen).
signal changed

const MAX_PLAYERS := 4
const MIN_TO_START := 2
const CODE_LENGTH := 4

## Verwechslungsarmes Alphabet: kein 0/O, kein 1/I/L. Am Telefon oder per
## Zuruf weitergegeben, ist ein Code aus diesen Zeichen eindeutig lesbar.
const CODE_ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

class Member extends RefCounted:
	var id: StringName
	var name: String
	var character: StringName
	var is_ready: bool = false

	func _init(p_id: StringName, p_name: String) -> void:
		id = p_id
		name = p_name


var code: String = ""
var host_id: StringName = &""
var started: bool = false
var members: Array[Member] = []


## Öffnet eine Lobby mit dem Host als erstem Mitglied.
##
## [param rng] erzeugt den Code. Im echten Spiel aus der Uhrzeit geseedet, im
## Test aus einem festen Seed — dann ist auch der Code reproduzierbar.
func open(host: StringName, host_name: String, rng: SeededRng) -> void:
	code = generate_code(rng)
	host_id = host
	started = false
	members.clear()
	members.append(Member.new(host, host_name))
	changed.emit()


## Versucht beizutreten. Gibt einen leeren String zurück bei Erfolg, sonst
## einen Grund (für die Fehleranzeige).
func join(player_id: StringName, player_name: String) -> String:
	if started:
		return "Die Partie läuft bereits"
	if members.size() >= MAX_PLAYERS:
		return "Die Runde ist voll"
	if _member(player_id) != null:
		return "Schon in der Lobby"
	members.append(Member.new(player_id, player_name))
	changed.emit()
	return ""


func set_ready(player_id: StringName, ready: bool) -> void:
	var m := _member(player_id)
	if m != null:
		m.is_ready = ready
		changed.emit()


func set_character(player_id: StringName, character: StringName) -> void:
	var m := _member(player_id)
	if m != null:
		m.character = character
		changed.emit()


## Entfernt ein Mitglied. Verlässt der Host, wandert die Rolle zum nächsten —
## sonst bliebe die Lobby führungslos (PLAN.md §4.2).
func leave(player_id: StringName) -> void:
	var idx := _index(player_id)
	if idx < 0:
		return
	members.remove_at(idx)
	if player_id == host_id and not members.is_empty():
		host_id = members[0].id
	changed.emit()


## Darf die Partie starten? Nur der Host, genug Spieler, alle bereit.
func can_start(requester: StringName) -> bool:
	if started or requester != host_id:
		return false
	if members.size() < MIN_TO_START:
		return false
	for m in members:
		if not m.is_ready:
			return false
	return true


func mark_started() -> void:
	started = true
	changed.emit()


## Die Mitglieder als Spielerdefinitionen für [method MatchServer.configure].
## Der Host bleibt an Position 0, die Reihenfolge ist damit stabil.
func to_player_defs() -> Array:
	var out: Array = []
	for m in members:
		out.append({
			"id": String(m.id),
			"name": m.name,
			"char": String(m.character),
			"ai": false,
		})
	return out


func player_count() -> int:
	return members.size()


## Erzeugt einen Beitrittscode aus dem verwechslungsarmen Alphabet.
static func generate_code(rng: SeededRng) -> String:
	var out := ""
	for i in CODE_LENGTH:
		out += CODE_ALPHABET[rng.next_int(0, CODE_ALPHABET.length() - 1)]
	return out


func _member(id: StringName) -> Member:
	for m in members:
		if m.id == id:
			return m
	return null


func _index(id: StringName) -> int:
	for i in members.size():
		if members[i].id == id:
			return i
	return -1
