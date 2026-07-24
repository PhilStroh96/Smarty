extends Node

## Zentrale Audio-Steuerung. Autoload: [code]Audio[/code].
##
## Gerüst für M0 — die eigentlichen Busse und Sounds kommen in M4.

const BUS_MASTER := "Master"

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

## Anzahl paralleler SFX-Kanäle. Party-Games spielen viele kurze Sounds
## gleichzeitig ab — ein einzelner Player würde sich selbst abschneiden.
const SFX_VOICES := 8


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	add_child(_music_player)

	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_sfx_players.append(p)

	Settings.changed.connect(_apply_volumes)
	_apply_volumes()


func play_music(stream: AudioStream, fade_sec: float = 0.5) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	if fade_sec > 0.0 and _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -60.0, fade_sec)
		await tween.finished
	_music_player.stream = stream
	_music_player.play()
	_apply_volumes()


func stop_music(fade_sec: float = 0.5) -> void:
	if not _music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -60.0, fade_sec)
	await tween.finished
	_music_player.stop()


## Spielt einen Effekt auf dem nächsten freien Kanal (Round-Robin).
func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var p := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_VOICES
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(maxf(Settings.sfx_volume, 0.0001))
	p.play()


func _apply_volumes() -> void:
	_music_player.volume_db = linear_to_db(maxf(Settings.music_volume, 0.0001))
