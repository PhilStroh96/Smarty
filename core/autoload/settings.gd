extends Node

## Persistente Nutzereinstellungen. Autoload: [code]Settings[/code].
##
## Die Barrierefreiheits-Optionen sind hier kein Nachgedanke: Bei
## Logik-Minispielen, die Farben unterscheiden lassen, ist ein
## Farbenblind-Modus funktional notwendig, nicht kosmetisch (PLAN.md §M6).

const SAVE_PATH := "user://settings.cfg"

signal changed

enum ColorMode {
	NORMAL,
	DEUTERANOPIA,  ## Rot-Grün-Schwäche, häufigste Form
	PROTANOPIA,
	TRITANOPIA,    ## Blau-Gelb-Schwäche
}

@export_range(0.0, 1.0) var music_volume: float = 0.7
@export_range(0.0, 1.0) var sfx_volume: float = 1.0

var color_mode: ColorMode = ColorMode.NORMAL

## Reduziert Bildschirmwackeln, Blitze und schnelle Übergänge.
var reduced_motion: bool = false

## Skaliert die UI-Schrift. Für kleine Displays und schwache Augen.
@export_range(0.8, 1.6) var text_scale: float = 1.0

## Haptisches Feedback bei Antworten.
var vibration: bool = true

## Leer = Systemsprache verwenden.
var language: String = ""


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # Erststart: Defaults behalten
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	color_mode = cfg.get_value("a11y", "color_mode", color_mode)
	reduced_motion = cfg.get_value("a11y", "reduced_motion", reduced_motion)
	text_scale = cfg.get_value("a11y", "text_scale", text_scale)
	vibration = cfg.get_value("input", "vibration", vibration)
	language = cfg.get_value("locale", "language", language)
	_apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("a11y", "color_mode", color_mode)
	cfg.set_value("a11y", "reduced_motion", reduced_motion)
	cfg.set_value("a11y", "text_scale", text_scale)
	cfg.set_value("input", "vibration", vibration)
	cfg.set_value("locale", "language", language)
	cfg.save(SAVE_PATH)
	_apply()
	changed.emit()


func _apply() -> void:
	if language != "":
		TranslationServer.set_locale(language)
