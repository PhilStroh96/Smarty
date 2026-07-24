class_name Pawn
extends Sprite2D

## Eine Spielfigur auf dem Brett.
##
## Bewegt sich Feld für Feld mit einem Hüpfbogen statt in einem Rutsch zum
## Ziel. Das ist nicht nur Zierde: Man sieht die Schritte einzeln und kann
## mitzählen — bei einem Brettspiel ist das Teil der Spannung.

const PAWN_TEXTURE := preload("res://assets/art/characters/pawns.png")
const PAWN_W := 48
const PAWN_H := 72

## Dauer eines einzelnen Feldsprungs.
const HOP_TIME := 0.28
## Scheitelhöhe des Sprungbogens in Pixeln.
const HOP_HEIGHT := 34.0

## Visueller Versatz je Spieler. Ohne ihn stünden vier Figuren auf demselben
## Feld exakt übereinander und man sähe nur die zuletzt gezeichnete.
const SLOT_OFFSETS := [
	Vector2(-17, -7), Vector2(17, -7),
	Vector2(-17, 7), Vector2(17, 7),
]

signal step_taken(field_index: int)
signal movement_finished(field_index: int)

var player_index: int = 0
var field_index: int = 0

var _board: BoardMap
var _moving: bool = false


func setup(p_player_index: int, board: BoardMap, start_field: int = 0) -> void:
	player_index = p_player_index
	_board = board
	field_index = start_field

	var at := AtlasTexture.new()
	at.atlas = PAWN_TEXTURE
	at.region = Rect2(player_index * PAWN_W, 0, PAWN_W, PAWN_H)
	texture = at
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Füße auf die Tile-Oberseite setzen statt die Figur zu zentrieren,
	# plus den Spielerversatz.
	#
	# Der Versatz steckt bewusst hier und nicht in [member position]:
	# Y-Sortierung wertet die Node-Position aus, ein negativer y-Versatz
	# würde die Figur hinter ihr eigenes Feld schieben. [member offset]
	# verschiebt nur die Textur und lässt die Sortierung unberührt.
	var slot: Vector2 = SLOT_OFFSETS[player_index % 4]
	offset = Vector2(slot.x, -PAWN_H / 2.0 + 6 + slot.y)
	position = _slot_position(field_index)


func is_moving() -> bool:
	return _moving


## Läuft [param steps] Felder weiter. Gibt den neuen Feldindex zurück.
##
## Muss awaited werden — die Rundenlogik wartet auf das Ende der Bewegung.
func move_steps(steps: int) -> int:
	if _moving or _board == null or steps <= 0:
		return field_index
	_moving = true

	for i in steps:
		var next := _board.wrap_index(field_index + 1)
		await _hop_to(next)
		field_index = next
		step_taken.emit(field_index)

	_moving = false
	movement_finished.emit(field_index)
	return field_index


## Setzt die Figur ohne Animation. Für Spielaufbau und Tests.
func teleport_to(index: int) -> void:
	field_index = _board.wrap_index(index) if _board else index
	position = _slot_position(field_index)


func _hop_to(target_index: int) -> void:
	var from := position
	var to := _slot_position(target_index)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			# Horizontal linear, vertikal ein Sinusbogen — ergibt den
			# Sprung, ohne für eine Figur eine Physik-Engine zu bemühen.
			position = from.lerp(to, t) - Vector2(0, sin(t * PI) * HOP_HEIGHT),
		0.0, 1.0, HOP_TIME
	).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	position = to


## Position der Figur auf einem Feld.
##
## Das +1 in y sorgt dafür, dass die Figur bei der Y-Sortierung hinter dem
## Feld einsortiert wird, auf dem sie steht — also davor gezeichnet wird.
func _slot_position(index: int) -> Vector2:
	if _board == null:
		return Vector2.ZERO
	return _board.field_position(index) + Vector2(0, 1)
