extends Node

## Zustand der laufenden Partie. Autoload: [code]GameState[/code].
##
## Gerüst für M0. In M3 wird das die Client-Spiegelung des autoritativen
## Server-Zustands — der Server bleibt die Wahrheit, das hier ist nur die
## Sicht des Clients darauf (PLAN.md §2.1).
##
## [b]Wichtig:[/b] Minispiele dürfen hier nicht zugreifen. Sie bekommen
## einen Seed und geben ein Ergebnis zurück, sonst nichts.

signal round_changed(round_index: int)
signal match_ended

enum Mode {
	ONLINE,  ## Lobby-Code, autoritativer Server
	LOCAL,   ## Hotseat auf einem Gerät — funktioniert offline
	SOLO,    ## Gegen KI
}

## Maximale Spielerzahl. Mehr Spieler = längere Wartezeiten pro Zug =
## tödlich für Mobile-Sessions (PLAN.md §8.2).
const MAX_PLAYERS := 4

class PlayerInfo extends RefCounted:
	var id: StringName
	var display_name: String = ""
	var character_id: StringName
	var is_ai: bool = false
	## Wird true, wenn die Verbindung abreißt und die KI übernimmt.
	var taken_over_by_ai: bool = false
	var coins: int = 0
	var stars: int = 0
	var board_position: int = 0
	var minigames_won: int = 0

	func _init(p_id: StringName = &"", p_name: String = "") -> void:
		id = p_id
		display_name = p_name


var mode: Mode = Mode.LOCAL
var players: Array[PlayerInfo] = []
var current_round: int = 0
var total_rounds: int = 12
var current_player_index: int = 0

## Der Seed der Partie. Vom Server vorgegeben; alle abgeleiteten Seeds
## (Karte, Minispiele, Ereignisse) entstehen daraus über [method SeededRng.fork].
var match_seed: int = 0

var _match_rng: SeededRng


func start_match(p_mode: Mode, p_players: Array[PlayerInfo], seed: int, rounds: int = 12) -> void:
	mode = p_mode
	players = p_players
	match_seed = seed
	total_rounds = rounds
	current_round = 0
	current_player_index = 0
	_match_rng = SeededRng.new(seed)


## Der Seed für ein bestimmtes Minispiel in einer bestimmten Runde.
##
## Abgeleitet statt fortlaufend gezogen: So ändert sich Runde 7 nicht,
## nur weil in Runde 3 eine Regel angepasst wurde.
func minigame_seed(round_index: int, minigame_slot: int = 0) -> int:
	return SeededRng.mix(match_seed, round_index * 31 + minigame_slot)


func advance_round() -> void:
	current_round += 1
	round_changed.emit(current_round)
	if current_round >= total_rounds:
		match_ended.emit()


func get_player(id: StringName) -> PlayerInfo:
	for p in players:
		if p.id == id:
			return p
	return null


## Rangliste nach Sternen, bei Gleichstand nach Münzen.
func standings() -> Array[PlayerInfo]:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: PlayerInfo, b: PlayerInfo) -> bool:
		if a.stars != b.stars:
			return a.stars > b.stars
		return a.coins > b.coins
	)
	return sorted
