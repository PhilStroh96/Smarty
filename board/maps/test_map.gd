class_name TestMap
extends RefCounted

## Die Testkarte für M1: ein rechteckiger Ring aus 24 Feldern.
##
## Fest definiert, nicht zufällig erzeugt — eine Karte ist Leveldesign,
## kein Zufallsprodukt. Später kommt pro Karte eine eigene Datei dazu.
##
## Layout (Gitterkoordinaten, im Uhrzeigersinn ab Start oben links):
## [codeblock]
##   0  1  2  3  4  5  6  7
##  23                    8
##  22                    9
##  21                   10
##  20                   11
##  19 18 17 16 15 14 13 12
## [/codeblock]

const WIDTH := 8
const HEIGHT := 6

## Feldtypen an bestimmten Ringpositionen. Alles nicht Genannte ist NORMAL.
##
## Die beiden Sternfelder liegen bewusst gegenüber (6 und 18), damit kein
## Spieler durch seine Startposition strukturell im Vorteil ist.
const SPECIALS := {
	0: TileTypes.Type.START,
	2: TileTypes.Type.BONUS,
	4: TileTypes.Type.FALLE,
	6: TileTypes.Type.STERN,
	9: TileTypes.Type.BONUS,
	11: TileTypes.Type.FALLE,
	14: TileTypes.Type.BONUS,
	16: TileTypes.Type.FALLE,
	18: TileTypes.Type.STERN,
	21: TileTypes.Type.BONUS,
	23: TileTypes.Type.FALLE,
}


## Erzeugt die Felddefinitionen für [method BoardMap.build].
static func build_fields() -> Array:
	var grids := _ring_coords()
	var out: Array = []
	for i in grids.size():
		out.append({
			"grid": grids[i],
			"type": SPECIALS.get(i, TileTypes.Type.NORMAL),
		})
	return out


## Die Gitterkoordinaten des Rings, im Uhrzeigersinn.
static func _ring_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	# Oben nach rechts
	for x in range(0, WIDTH):
		out.append(Vector2i(x, 0))
	# Rechte Kante nach unten
	for y in range(1, HEIGHT):
		out.append(Vector2i(WIDTH - 1, y))
	# Unten nach links
	for x in range(WIDTH - 2, -1, -1):
		out.append(Vector2i(x, HEIGHT - 1))
	# Linke Kante nach oben
	for y in range(HEIGHT - 2, 0, -1):
		out.append(Vector2i(0, y))
	return out


## Der Mittelpunkt der Karte in Weltkoordinaten — Startposition der Kamera.
static func world_center() -> Vector2:
	return BoardMap.grid_to_world(Vector2i(WIDTH - 1, HEIGHT - 1)) * 0.5
