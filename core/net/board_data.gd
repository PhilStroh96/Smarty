class_name BoardData
extends RefCounted

## Die reine Spiellogik des Bretts — ohne Szene, ohne Sprites.
##
## [BoardMap] ist ein [Node2D] und erzeugt Grafik; der [MatchServer] läuft
## aber headless und darf keine Szene instanziieren. Diese Klasse trägt
## deshalb die Feldtypen und die Bewegungslogik als reine Daten. [BoardMap]
## baut intern dieselbe [BoardData] und leitet [method wrap_index] und
## [method passed_start] hierher weiter — so gibt es genau eine
## Implementierung, die auf Client und Server dieselben Ergebnisse liefert.

## Feldtypen entlang des Rings. Der Index ist die Position.
var types: Array[int] = []


func _init(field_defs: Array = []) -> void:
	for d in field_defs:
		types.append(d["type"])


func size() -> int:
	return types.size()


## Der Feldtyp an einer (ggf. über den Ring hinaus laufenden) Position.
func field_type(index: int) -> int:
	if types.is_empty():
		return TileTypes.Type.NORMAL
	return types[wrap_index(index)]


## Normalisiert einen Feldindex auf den geschlossenen Ring.
func wrap_index(index: int) -> int:
	if types.is_empty():
		return 0
	return wrapi(index, 0, types.size())


## Prüft, ob zwischen zwei Zügen das Startfeld (Index 0) überschritten wurde.
##
## Wichtig für die Startfeld-Prämie: Wer über Start hinweggeht, bekommt sie
## auch dann, wenn er nicht exakt darauf landet.
func passed_start(from_index: int, steps: int) -> bool:
	if types.is_empty() or steps <= 0:
		return false
	for i in range(1, steps + 1):
		if wrap_index(from_index + i) == 0:
			return true
	return false
