class_name SeededRng
extends RefCounted

## Deterministische Zufallsquelle — die EINZIGE erlaubte in Spiellogik.
##
## Godots globales [code]randi()[/code]/[code]randf()[/code] und
## [code]Array.shuffle()[/code] sind in [code]minigames/[/code] und
## [code]board/[/code] verboten. Sie ziehen aus einem globalen, nicht
## reproduzierbaren Zustand und brechen damit die Server-Validierung.
##
## Hintergrund (PLAN.md §2.1): Minispiele werden nicht über das Netz
## synchronisiert. Server und alle Clients erzeugen aus demselben Seed
## dieselbe Aufgabenfolge; übertragen werden nur Antworten und Zeiten.
## Das funktioniert nur, wenn jeder Aufruf hier auf jeder Plattform
## bitgleiche Ergebnisse liefert.
##
## [codeblock]
## var rng := SeededRng.new(match_seed)
## var aufgabe := rng.next_int(1, 20)
## var optionen := rng.shuffled(["A", "B", "C", "D"])
## [/codeblock]

const _U32 := 4294967296.0  # 2^32, für die Float-Ableitung

var _rng := RandomNumberGenerator.new()
var _seed: int = 0


func _init(initial_seed: int = 0) -> void:
	reset(initial_seed)


## Setzt den Generator auf einen Seed zurück. Gleicher Seed -> gleiche Folge.
func reset(new_seed: int) -> void:
	_seed = new_seed
	_rng.seed = new_seed


## Der Seed, mit dem dieser Generator initialisiert wurde.
func get_seed() -> int:
	return _seed


## Ganzzahl in [from, to] — beide Grenzen inklusive.
func next_int(from: int, to: int) -> int:
	if to <= from:
		return from
	# Bewusst über randi() + Modulo statt randi_range(): garantiert
	# identisches Verhalten über Godot-Versionen und Plattformen hinweg.
	# Der minimale Modulo-Bias ist für ein Party-Game irrelevant.
	return from + (_rng.randi() % (to - from + 1))


## Kommazahl in [0, 1).
##
## Aus einer Ganzzahl abgeleitet statt über randf(): Float-Erzeugung ist
## die wahrscheinlichste Quelle für Plattform-Abweichungen.
func next_float() -> float:
	return float(_rng.randi()) / _U32


## Kommazahl in [from, to).
func next_float_range(from: float, to: float) -> float:
	return from + next_float() * (to - from)


## True mit Wahrscheinlichkeit [param probability] (0.0 bis 1.0).
func chance(probability: float) -> bool:
	return next_float() < probability


## Ein zufälliges Element aus [param arr]. Verändert das Array nicht.
func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[next_int(0, arr.size() - 1)]


## [param count] verschiedene Elemente aus [param arr], ohne Zurücklegen.
func pick_many(arr: Array, count: int) -> Array:
	var pool := shuffled(arr)
	return pool.slice(0, mini(count, pool.size()))


## Mischt [param arr] an Ort und Stelle (Fisher-Yates).
##
## Ersetzt [code]Array.shuffle()[/code], das den globalen RNG benutzt.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := next_int(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Wie [method shuffle], gibt aber eine gemischte Kopie zurück.
func shuffled(arr: Array) -> Array:
	var copy := arr.duplicate()
	shuffle(copy)
	return copy


## Ein abgeleiteter Generator für einen Teilbereich.
##
## Nutzen: Änderungen an einer Stelle verschieben nicht die Zufallsfolge
## aller anderen. Ein Minispiel, das [code]fork(3)[/code] für Aufgabe 3
## benutzt, erzeugt dieselbe Aufgabe, auch wenn Aufgabe 2 später mehr
## Zufallswerte zieht als vorher.
func fork(salt: int) -> SeededRng:
	return SeededRng.new(mix(_seed, salt))


## Mischt zwei Ganzzahlen zu einem neuen Seed. Deterministisch.
static func mix(a: int, b: int) -> int:
	var h: int = a * 1099087573 + b * 2654435761 + 12345
	h = h ^ (h >> 16)
	h = h * 2246822519
	h = h ^ (h >> 13)
	h = h * 3266489917
	h = h ^ (h >> 16)
	return absi(h)
