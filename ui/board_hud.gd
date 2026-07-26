class_name BoardHud
extends CanvasLayer

## Die Bedienoberfläche über dem Spielbrett.
##
## Per Code aufgebaut statt als .tscn: Das HUD ist zu diesem Zeitpunkt noch
## reine Funktion, und Platzhalter-Layouts in einer Szenendatei erzeugen nur
## Merge-Konflikte. Sobald das UI-Kit aus M4 steht, wird das hier ersetzt.

signal roll_pressed

## Mindestgröße für Touch-Ziele in Pixeln (PLAN.md §2.6). Bei
## Zeitdruck-Elementen eher großzügiger.
const TOUCH_MIN := 96

# Exakt die Figurenfarben (Prisma, docs/art-bible.md), damit "Du" im HUD
# dieselbe Farbe hat wie die eigene Figur auf dem Brett.
const PLAYER_COLORS := [
	Color("#ff4d5e"), Color("#2e9bff"), Color("#ffc93c"), Color("#1fb36b"),
]

var _round_label: Label
var _turn_label: Label
var _dice_label: Label
var _message_label: Label
var _roll_button: Button
var _player_rows: Array[Label] = []


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Großzügige Ränder, damit nichts unter Notch oder Gestenleiste
	# verschwindet (PLAN.md §2.6).
	for side in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 48)
	add_child(root)

	# --- Kopfzeile: Spielerstände ---
	var top := VBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_theme_constant_override("separation", 6)
	root.add_child(top)

	_round_label = _make_label("Runde -", 30, Color("#ffd369"))
	top.add_child(_round_label)

	for i in GameState.players.size():
		var l := _make_label("", 26, PLAYER_COLORS[i % 4])
		top.add_child(l)
		_player_rows.append(l)

	# --- Fußzeile: Zuginfo und Würfelknopf ---
	var bottom := VBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	_message_label = _make_label("", 30, Color("#ffd369"))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_message_label)

	_dice_label = _make_label("", 44, Color.WHITE)
	_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_dice_label)

	_turn_label = _make_label("", 28, Color.WHITE)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_turn_label)

	_roll_button = Button.new()
	_roll_button.text = "Würfeln"
	_roll_button.custom_minimum_size = Vector2(0, TOUCH_MIN)
	_roll_button.add_theme_font_size_override("font_size", 36)
	_roll_button.pressed.connect(func() -> void: roll_pressed.emit())
	bottom.add_child(_roll_button)

	refresh()


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#1b1b2f"))
	l.add_theme_constant_override("outline_size", 6)
	return l


## Aktualisiert alle Spielerstände.
func refresh() -> void:
	_round_label.text = "Runde %d / %d" % [
		mini(GameState.current_round + 1, GameState.total_rounds),
		GameState.total_rounds,
	]
	for i in _player_rows.size():
		var p: PlayerInfo = GameState.players[i]
		var marker := "> " if i == GameState.current_player_index else "   "
		_player_rows[i].text = "%s%s   %d Sterne   %d Münzen" % [
			marker, p.display_name, p.stars, p.coins
		]


func set_turn(player_index: int) -> void:
	var p: PlayerInfo = GameState.players[player_index]
	# Der lokale Spieler wird angesprochen, nicht über seinen Namen
	# benannt — "Du ist dran" wäre der Klassiker unter den Platzhaltertexten,
	# die es bis in einen Release schaffen.
	_turn_label.text = "Du bist dran" if not p.is_computer_controlled() \
		else "%s ist dran" % p.display_name
	_dice_label.text = ""
	_message_label.text = ""
	# Nur der menschliche Spieler bekommt den Knopf.
	_roll_button.visible = not p.is_computer_controlled()
	_roll_button.disabled = false
	refresh()


func set_dice(value: int) -> void:
	_dice_label.text = "Würfel: %d" % value
	_roll_button.disabled = true


func set_message(text: String) -> void:
	_message_label.text = text
	refresh()


## Zeigt, wer im Minispiel wie viele Münzen bekommen hat.
func show_minigame_result(rewards: Array) -> void:
	var parts: Array[String] = []
	for i in rewards.size():
		if i < GameState.players.size():
			parts.append("%s +%d" % [GameState.players[i].display_name, rewards[i]])
	_message_label.text = "Minispiel: " + "   ".join(parts)
	refresh()


func show_result() -> void:
	_roll_button.visible = false
	_turn_label.text = ""
	_dice_label.text = ""
	var standings := GameState.standings()
	var lines: Array[String] = ["Endstand"]
	for i in standings.size():
		lines.append("%d. %s - %d Sterne, %d Münzen" % [
			i + 1, standings[i].display_name, standings[i].stars, standings[i].coins
		])
	_message_label.text = "\n".join(lines)
