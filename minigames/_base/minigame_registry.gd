class_name MinigameRegistry
extends RefCounted

## Katalog aller Minispiele.
##
## Eine Liste statt einer Verzeichnissuche: Ein Minispiel ist erst dann im
## Spiel, wenn es hier bewusst eingetragen wurde. Ein halbfertiges Spiel im
## Ordner soll nicht versehentlich in einer Partie auftauchen.
##
## Ein neues Minispiel eintragen heißt: Szenenpfad, Titel und Kategorie
## hier ergänzen. Mehr nicht.

const ENTRIES := [
	{
		"id": &"rechnen_zielzahl",
		"title": "Zielzahl",
		"category": MinigameBase.Category.RECHNEN,
		"scene": "res://minigames/rechnen/zielzahl/zielzahl.tscn",
	},
	{
		"id": &"erkennen_mehr",
		"title": "Mehr davon",
		"category": MinigameBase.Category.ERKENNEN,
		"scene": "res://minigames/erkennen/mehr/mehr.tscn",
	},
	{
		"id": &"erkennen_farbwort",
		"title": "Farbe oder Wort",
		"category": MinigameBase.Category.ERKENNEN,
		"scene": "res://minigames/erkennen/farbwort/farbwort.tscn",
	},
	{
		"id": &"analysieren_reihe",
		"title": "Wie geht es weiter",
		"category": MinigameBase.Category.ANALYSIEREN,
		"scene": "res://minigames/analysieren/reihe/reihe.tscn",
	},
	{
		"id": &"vorstellen_drehung",
		"title": "Gedreht",
		"category": MinigameBase.Category.VORSTELLEN,
		"scene": "res://minigames/vorstellen/drehung/drehung.tscn",
	},
	{
		"id": &"merken_paare",
		"title": "Kurz gemerkt",
		"category": MinigameBase.Category.MERKEN,
		"scene": "res://minigames/merken/paare/paare.tscn",
	},
]


static func all() -> Array:
	return ENTRIES


static func by_id(id: StringName) -> Dictionary:
	for e in ENTRIES:
		if e["id"] == id:
			return e
	return {}


static func by_category(category: MinigameBase.Category) -> Array:
	var out: Array = []
	for e in ENTRIES:
		if e["category"] == category:
			out.append(e)
	return out


## Wählt ein Minispiel für eine Runde aus.
##
## Deterministisch aus Match-Seed und Runde abgeleitet, damit alle Clients
## dasselbe Spiel laden (PLAN.md §2.1).
##
## [param recent] enthält zuletzt gespielte IDs; sie werden übersprungen,
## solange noch andere zur Wahl stehen. Ohne das kommt dasselbe Spiel in
## einer kurzen Partie zwei-, dreimal — bei 12 Runden und wenigen Spielen
## fällt das sofort unangenehm auf.
static func pick(match_seed: int, round_index: int, recent: Array = []) -> Dictionary:
	if ENTRIES.is_empty():
		return {}

	var pool: Array = []
	for e in ENTRIES:
		if not recent.has(e["id"]):
			pool.append(e)
	if pool.is_empty():
		pool = ENTRIES.duplicate()

	var picker := SeededRng.new(SeededRng.mix(match_seed, 7777 + round_index))
	return picker.pick(pool)
