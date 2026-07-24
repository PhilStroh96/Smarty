class_name PlayerInfo
extends RefCounted

## Der Zustand eines Spielers in einer laufenden Partie.
##
## Bewusst eine eigene Klasse und keine innere Klasse von [GameState]:
## Rundenlogik, HUD, Netzwerkschicht und Tests brauchen den Typ alle, und
## eine innere Klasse eines Autoloads ist außerhalb des laufenden
## Spielbaums nicht referenzierbar — headless-Tests scheitern daran.

var id: StringName
var display_name: String = ""
var character_id: StringName
var is_ai: bool = false

## Wird true, wenn die Verbindung abreißt und die KI übernimmt.
## Bei mobilen Spielern ist das der Normalfall, nicht die Ausnahme
## (PLAN.md §4.2).
var taken_over_by_ai: bool = false

var coins: int = 0
var stars: int = 0
var board_position: int = 0
var minigames_won: int = 0


func _init(p_id: StringName = &"", p_name: String = "") -> void:
	id = p_id
	display_name = p_name


## Wird dieser Spieler von der KI gesteuert — dauerhaft oder übergangsweise?
func is_computer_controlled() -> bool:
	return is_ai or taken_over_by_ai


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"character": String(character_id),
		"coins": coins,
		"stars": stars,
		"position": board_position,
		"minigames_won": minigames_won,
	}


static func from_dict(d: Dictionary) -> PlayerInfo:
	var p := PlayerInfo.new(StringName(d.get("id", "")), d.get("name", ""))
	p.character_id = StringName(d.get("character", ""))
	p.coins = d.get("coins", 0)
	p.stars = d.get("stars", 0)
	p.board_position = d.get("position", 0)
	p.minigames_won = d.get("minigames_won", 0)
	return p
