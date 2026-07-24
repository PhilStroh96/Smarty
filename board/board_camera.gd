class_name BoardCamera
extends Camera2D

## Kamera über dem Spielbrett.
##
## Zwei Betriebsarten:
## [br]• [method frame_board] rahmt das gesamte Spielfeld ein. Richtig für
##   kompakte Karten — man sieht, wo die Gegner stehen und wo die
##   Sternfelder liegen, was bei einem Party-Brettspiel die halbe Taktik ist.
## [br]• [member target] folgt einer Figur. Wird gebraucht, sobald Karten
##   größer sind als der Bildschirm.
##
## Das Glätten übernimmt Godots [member Camera2D.position_smoothing_enabled] —
## selbst nachzubauen wäre framerate-abhängig.

## Obergrenze für den automatischen Zoom. Weiter heranzugehen macht die
## Figuren nicht lesbarer, schneidet aber Spielfeld ab.
const MAX_AUTO_ZOOM := 1.6

## Platz, den das HUD am unteren Rand beansprucht (Zielauflösungspixel).
## Ohne diese Reserve verschwinden die untersten Felder hinter dem
## Würfelknopf.
const HUD_BOTTOM_RESERVE := 260.0

## Platz am oberen Rand: dort stehen die Spielerstände, und die Figuren
## ragen rund 70 px über ihr Feld hinaus. [method BoardMap.world_bounds]
## kennt nur die Tile-Fläche — ohne diese Reserve werden die Figuren auf
## den obersten Feldern abgeschnitten.
const HUD_TOP_RESERVE := 280.0

## Seitlicher Rand, damit das Brett nicht bündig an der Kante klebt.
const SIDE_MARGIN := 80.0

var target: Node2D:
	set(value):
		target = value
		if target != null and not _initialised:
			global_position = target.global_position
			_initialised = true

var _initialised: bool = false


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 12.0 if Settings.reduced_motion else 4.0


func _process(_delta: float) -> void:
	if target != null:
		global_position = target.global_position


## Wählt Zoom und Position so, dass das ganze Brett sichtbar bleibt und
## unten Platz für das HUD frei ist. Schaltet das Verfolgen ab.
func frame_board(board: BoardMap) -> void:
	target = null
	_initialised = true

	var bounds := board.world_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	var vp := get_viewport_rect().size
	var usable := Vector2(
		maxf(vp.x - SIDE_MARGIN * 2.0, 1.0),
		maxf(vp.y - HUD_BOTTOM_RESERVE - HUD_TOP_RESERVE, 1.0)
	)

	var z := minf(usable.x / bounds.size.x, usable.y / bounds.size.y)
	z = minf(z, MAX_AUTO_ZOOM)
	zoom = Vector2(z, z)

	# Das Brett in den freien Bereich zwischen den Reserven zentrieren,
	# nicht in den ganzen Bildschirm — sonst rutscht es unter das HUD.
	var shift := (HUD_BOTTOM_RESERVE - HUD_TOP_RESERVE) / (2.0 * z)
	global_position = bounds.get_center() + Vector2(0, shift)
	reset_smoothing()
