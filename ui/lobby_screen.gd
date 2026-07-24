extends Control

## Der Lobby-Bildschirm: Raum erstellen (Host) oder per Code beitreten (Gast).
##
## Aufbau per Code wie die übrige UI. Die Session ([HostSession]/[GuestSession])
## wird an die Baum-Wurzel gehängt, damit sie den Szenenwechsel in die Brettphase
## überlebt; die Brettszene schließt sie am Ende über [MatchSetup].teardown.
##
## [b]Ohne deployten Relay[/b] (Settings.relay_url leer) zeigt der Bildschirm
## den Ablauf, weist aber darauf hin, dass echte Verbindungen erst mit dem
## Worker möglich sind (server/relay-worker/README.md).

const MENU_SCENE := "res://ui/main_menu.tscn"
const BOARD_SCENE := "res://board/board_scene.tscn"

const BG := Color("#1b1b2f")
const ACCENT := Color("#ffd369")
const WARN := Color("#ff9f43")
const TOUCH_MIN := 96

enum View { CHOICE, CREATE, JOIN }

var _content: VBoxContainer
var _member_label: Label
var _status_label: Label

var _session: Node          # HostSession oder GuestSession
var _is_host := false
var _handed_off := false
var _code := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	_show(View.CHOICE)


func _exit_tree() -> void:
	# Verlassen wir die Lobby, ohne zu starten, die Session sauber schließen.
	if _session != null and not _handed_off and is_instance_valid(_session):
		_session.call("shutdown")


func _build_frame() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	add_child(margin)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 20)
	margin.add_child(_content)


func _show(view: View) -> void:
	for c in _content.get_children():
		c.queue_free()

	match view:
		View.CHOICE:
			_content.add_child(_heading("Online spielen"))
			if Settings.relay_url == "":
				_content.add_child(_note(
					"Hinweis: Der Online-Relay ist noch nicht eingerichtet.\n"
					+ "Du kannst den Ablauf sehen, aber Freunde können erst\n"
					+ "beitreten, wenn der Worker läuft (server/relay-worker).", WARN))
			_content.add_child(_spacer(20))
			_content.add_child(_button("Raum erstellen", func() -> void: _show(View.CREATE)))
			_content.add_child(_button("Raum beitreten", func() -> void: _show(View.JOIN)))
			_content.add_child(_button("Zurück", _back, false))

		View.CREATE:
			_is_host = true
			_code = _new_code()
			_content.add_child(_heading("Dein Raum-Code"))
			var code_label := _heading(_code)
			code_label.add_theme_font_size_override("font_size", 96)
			_content.add_child(code_label)
			_content.add_child(_note("Teile den Code mit deinen Freunden.", Color("#c8c8d8")))
			_member_label = _note("", Color.WHITE)
			_content.add_child(_member_label)
			_status_label = _note("", WARN)
			_content.add_child(_status_label)
			_content.add_child(_spacer(16))
			_content.add_child(_button("Starten", _on_start))
			_content.add_child(_button("Zurück", _back, false))
			_begin_host()

		View.JOIN:
			_is_host = false
			_content.add_child(_heading("Raum beitreten"))
			var code_input := LineEdit.new()
			code_input.placeholder_text = "CODE"
			code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
			code_input.custom_minimum_size = Vector2(0, TOUCH_MIN)
			code_input.add_theme_font_size_override("font_size", 48)
			code_input.max_length = Lobby.CODE_LENGTH
			_content.add_child(code_input)
			_member_label = _note("", Color.WHITE)
			_content.add_child(_member_label)
			_status_label = _note("", WARN)
			_content.add_child(_status_label)
			_content.add_child(_spacer(16))
			_content.add_child(_button("Beitreten", func() -> void:
				_begin_guest(code_input.text.strip_edges().to_upper())))
			_content.add_child(_button("Zurück", _back, false))


# ---------------------------------------------------------------------------
# Host / Gast
# ---------------------------------------------------------------------------

func _begin_host() -> void:
	if Settings.relay_url == "":
		_status_label.text = "Kein Relay verbunden — Start nur mit Worker möglich."
		return
	var endpoint := _make_endpoint(_code)
	var host := HostSession.new()
	get_tree().root.add_child(host)   # überlebt den Szenenwechsel
	_session = host
	host.lobby_updated.connect(_on_lobby)
	host.setup(endpoint, StringName(Settings.player_id), Settings.player_name, _code)
	(endpoint as WebSocketEndpoint).connect_to_relay()
	_status_label.text = "Verbinde …"


func _begin_guest(code: String) -> void:
	if code.length() != Lobby.CODE_LENGTH:
		_status_label.text = "Bitte einen %d-stelligen Code eingeben." % Lobby.CODE_LENGTH
		return
	if Settings.relay_url == "":
		_status_label.text = "Kein Relay verbunden — Beitritt nur mit Worker möglich."
		return
	_code = code
	var endpoint := _make_endpoint(code)
	var guest := GuestSession.new()
	get_tree().root.add_child(guest)
	_session = guest
	guest.lobby_updated.connect(_on_lobby)
	guest.match_ready.connect(_on_match_ready)
	guest.setup(endpoint, StringName(Settings.player_id), Settings.player_name, code)
	(endpoint as WebSocketEndpoint).connect_to_relay()
	_status_label.text = "Verbinde …"


func _make_endpoint(code: String) -> WebSocketEndpoint:
	return WebSocketEndpoint.new(Settings.relay_url, code, Settings.player_id, Settings.player_name)


func _on_lobby(_host_id: String, members: Array) -> void:
	if _status_label != null:
		_status_label.text = ""
	if _member_label == null:
		return
	var names: Array[String] = []
	for m in members:
		names.append(m.get("name", "?"))
	_member_label.text = "Im Raum: " + ", ".join(names)


func _on_start() -> void:
	if not _is_host or _session == null:
		return
	if not _session.call("can_start"):
		_status_label.text = "Es fehlt noch mindestens ein Mitspieler."
		return
	_session.call("start_match")
	_handed_off = true
	get_tree().change_scene_to_file(BOARD_SCENE)


func _on_match_ready() -> void:
	# Der Host hat gestartet — ab ins Spiel. Die Session ist bereits in der
	# Wurzel und übergibt ihren Client über MatchSetup.
	_handed_off = true
	get_tree().change_scene_to_file(BOARD_SCENE)


func _back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


# ---------------------------------------------------------------------------
# UI-Bausteine
# ---------------------------------------------------------------------------

func _new_code() -> String:
	return Lobby.generate_code(SeededRng.new(
		int(Time.get_unix_time_from_system()) ^ (randi() << 8)))


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 54)
	l.add_theme_color_override("font_color", ACCENT)
	return l


func _note(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, cb: Callable, primary: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH_MIN if primary else TOUCH_MIN * 0.8)
	b.add_theme_font_size_override("font_size", 36 if primary else 28)
	b.pressed.connect(cb)
	return b


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
