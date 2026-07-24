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

## Anzeigename in der Lobby.
var player_name: String = "Spieler"

## Stabile, anonyme Spieler-ID (kein Klarname, keine Kontodaten — Datensparsam-
## keit, PLAN.md §5.2). Wird einmalig erzeugt und behalten.
var player_id: String = ""

## URL des Relay-Workers (Cloudflare). Leer, bis der Worker deployt ist —
## siehe server/relay-worker/README.md. Dann z. B. wss://…workers.dev
var relay_url: String = ""


func _ready() -> void:
	load_settings()
	_ensure_player_id()


## Erzeugt einmalig eine anonyme Spieler-ID, falls noch keine da ist.
func _ensure_player_id() -> void:
	if player_id == "":
		# Anonym und stabil: Zufallsanteil plus Zeitstempel. Keine Geräte-
		# kennung, kein Klarname — Datensparsamkeit (PLAN.md §5.2).
		var rng := SeededRng.new(int(Time.get_unix_time_from_system()) ^ (randi() << 8))
		var alphabet := "abcdefghijklmnopqrstuvwxyz0123456789"
		var out := "u_"
		for i in 12:
			out += alphabet[rng.next_int(0, alphabet.length() - 1)]
		player_id = out


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
	player_name = cfg.get_value("player", "name", player_name)
	player_id = cfg.get_value("player", "id", player_id)
	relay_url = cfg.get_value("net", "relay_url", relay_url)
	_ensure_player_id()
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
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "id", player_id)
	cfg.set_value("net", "relay_url", relay_url)
	cfg.save(SAVE_PATH)
	_apply()
	changed.emit()


func _apply() -> void:
	if language != "":
		TranslationServer.set_locale(language)
