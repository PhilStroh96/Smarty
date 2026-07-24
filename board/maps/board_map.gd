class_name BoardMap
extends Node2D

## Das Spielbrett: ein geschlossener Ring aus Feldern.
##
## Bewusst kein TileMapLayer. Ein Party-Board ist ein Pfad aus Spielobjekten
## mit eigenem Zustand, keine Fläche aus Deko-Kacheln — als einzelne Nodes
## kann jedes Feld später eigene Effekte, Animationen und Trefferflächen
## tragen. Bei ~25 Feldern ist das performanceseitig belanglos.
##
## Die Reihenfolge im Array [b]ist[/b] der Spielpfad: Feld 0 -> 1 -> ... -> 0.

## Verbindliche Tile-Maße (PLAN.md §2.5). Diamant-Oberseite in 2:1-Projektion.
const TILE_W := 128
const TILE_H := 64
## Höhe der Seitenflächen — die Textur ist entsprechend höher als der Diamant.
const SIDE_H := 20

const TILE_TEXTURE := preload("res://assets/art/tiles/board_tiles.png")

class Field extends RefCounted:
	var grid: Vector2i
	var type: TileTypes.Type
	var index: int

	func _init(p_grid: Vector2i, p_type: TileTypes.Type, p_index: int) -> void:
		grid = p_grid
		type = p_type
		index = p_index


var fields: Array[Field] = []

var _tile_nodes: Array[Sprite2D] = []
var _atlas_cache: Dictionary = {}


func _ready() -> void:
	# Ohne Y-Sortierung überlappen weiter hinten liegende Tiles die
	# vorderen — das zerstört den Tiefeneindruck sofort.
	y_sort_enabled = true


## Rechnet Gitterkoordinaten in Weltkoordinaten um (2:1-Isometrie).
##
## Der Ursprung liegt in der Mitte der Diamant-Oberseite.
static func grid_to_world(grid: Vector2i) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * (TILE_W / 2.0),
		(grid.x + grid.y) * (TILE_H / 2.0)
	)


## Baut das Brett aus einer Feldliste auf.
func build(field_defs: Array) -> void:
	_clear()
	for i in field_defs.size():
		var d: Dictionary = field_defs[i]
		var f := Field.new(d["grid"], d["type"], i)
		fields.append(f)
		_spawn_tile(f)


func _clear() -> void:
	for n in _tile_nodes:
		n.queue_free()
	_tile_nodes.clear()
	fields.clear()


func _spawn_tile(f: Field) -> void:
	var s := Sprite2D.new()
	s.texture = _atlas_region(TileTypes.atlas_index(f.type))
	s.position = grid_to_world(f.grid)
	# Der Sprite ist höher als der Diamant (Seitenflächen). Ohne diese
	# Verschiebung säße die Oberseite zu tief und der Ring würde
	# auseinanderdriften.
	s.offset = Vector2(0, SIDE_H / 2.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	_tile_nodes.append(s)


func _atlas_region(index: int) -> AtlasTexture:
	if _atlas_cache.has(index):
		return _atlas_cache[index]
	var at := AtlasTexture.new()
	at.atlas = TILE_TEXTURE
	at.region = Rect2(index * TILE_W, 0, TILE_W, TILE_H + SIDE_H)
	_atlas_cache[index] = at
	return at


func size() -> int:
	return fields.size()


## Die Ausdehnung des Bretts in Weltkoordinaten, inklusive Tile-Fläche.
##
## Die Kamera braucht das, um das Spielfeld einzurahmen statt blind auf
## einer Figur zu kleben.
func world_bounds() -> Rect2:
	if fields.is_empty():
		return Rect2()
	var min_p := grid_to_world(fields[0].grid)
	var max_p := min_p
	for f in fields:
		var p := grid_to_world(f.grid)
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	# Ein Tile ragt über seinen Mittelpunkt hinaus — sonst schneidet die
	# Kamera die äußeren Felder an.
	var pad := Vector2(TILE_W / 2.0, (TILE_H + SIDE_H) / 2.0)
	return Rect2(min_p - pad, (max_p - min_p) + pad * 2.0)


func get_field(index: int) -> Field:
	if fields.is_empty():
		return null
	return fields[wrapi(index, 0, fields.size())]


## Weltposition, auf der eine Figur auf diesem Feld steht.
func field_position(index: int) -> Vector2:
	var f := get_field(index)
	if f == null:
		return Vector2.ZERO
	return grid_to_world(f.grid)


## Normalisiert einen Feldindex auf den Ring.
func wrap_index(index: int) -> int:
	if fields.is_empty():
		return 0
	return wrapi(index, 0, fields.size())


## Prüft, ob zwischen zwei Zügen das Startfeld überschritten wurde.
##
## Wichtig für die Startfeld-Prämie: Wer über Start hinweggeht, bekommt sie
## auch dann, wenn er nicht exakt darauf landet.
func passed_start(from_index: int, steps: int) -> bool:
	if fields.is_empty() or steps <= 0:
		return false
	for i in range(1, steps + 1):
		if wrap_index(from_index + i) == 0:
			return true
	return false
