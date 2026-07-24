class_name TileTypes
extends RefCounted

## Feldtypen des Spielbretts und ihre Effekte.
##
## Die Effekte stehen bewusst als reine Daten hier und nicht verteilt in
## der Rundenlogik — so ist eine neue Feldart eine Zeile in [constant EFFECTS]
## und nicht ein weiterer Zweig in einer match-Kaskade.

enum Type {
	NORMAL,  ## Passiert nichts
	BONUS,   ## Münzen dazu
	FALLE,   ## Münzen weg
	STERN,   ## Stern kaufen, wenn genug Münzen da sind
	START,   ## Runde vollendet, Münzen dazu
	DEKO,    ## Kein Spielfeld, nur Untergrund
}

## Index in assets/art/tiles/board_tiles.png (6 Tiles nebeneinander).
## Reihenfolge muss zu TILE_TYPES in tools/gen_placeholder_art.py passen.
const ATLAS_INDEX := {
	Type.NORMAL: 0,
	Type.BONUS: 1,
	Type.FALLE: 2,
	Type.STERN: 3,
	Type.START: 4,
	Type.DEKO: 5,
}

## Münz- und Sternänderung beim Betreten.
##
## Die Werte sind für M1 grob gesetzt. Echtes Balancing kommt in M5 —
## dafür braucht es erst Minispiele, die Münzen ausschütten.
const EFFECTS := {
	Type.NORMAL: {"coins": 0, "label": ""},
	Type.BONUS: {"coins": 3, "label": "+3 Münzen"},
	Type.FALLE: {"coins": -3, "label": "-3 Münzen"},
	Type.STERN: {"coins": 0, "label": "Stern!"},
	Type.START: {"coins": 10, "label": "+10 Münzen"},
	Type.DEKO: {"coins": 0, "label": ""},
}

## Was ein Stern kostet, wenn man auf einem STERN-Feld landet.
##
## [b]Vorläufiger M1-Wert.[/b] Die Hauptquelle für Münzen sind Minispiele,
## und die gibt es erst ab M2. Ohne sie bleiben pro Ringumlauf netto rund
## 10 Münzen übrig (4x Bonus, 4x Falle, einmal über Start) — bei 12 Runden
## schafft damit niemand die klassischen 20, und es fällt in einer ganzen
## Partie kein einziger Stern. Ein Brettspiel ohne erreichbares Ziel kann
## man nicht testspielen, deshalb hier vorerst 10.
##
## Mit den ersten Minispielen muss dieser Wert zusammen mit der
## Münzausschüttung neu justiert werden (PLAN.md M5, Balancing).
const STAR_PRICE := 10

const NAMES := {
	Type.NORMAL: "Normal",
	Type.BONUS: "Bonus",
	Type.FALLE: "Falle",
	Type.STERN: "Stern",
	Type.START: "Start",
	Type.DEKO: "Deko",
}


static func atlas_index(t: Type) -> int:
	return ATLAS_INDEX.get(t, 0)


static func coin_delta(t: Type) -> int:
	return EFFECTS.get(t, {}).get("coins", 0)


static func label(t: Type) -> String:
	return EFFECTS.get(t, {}).get("label", "")


static func type_name(t: Type) -> String:
	return NAMES.get(t, "?")
