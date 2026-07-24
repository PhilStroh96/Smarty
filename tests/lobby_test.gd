extends Node

## Prüft die Lobby-Zustandsmaschine.
##
##     godot --headless --path . res://tests/lobby_test.tscn
##
## Exit-Code 0 = alles grün, 1 = Fehler.

const SEED := 555

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	print("Lobby-Test")
	print("")

	_test_open()
	_test_join()
	_test_capacity()
	_test_ready_and_start()
	_test_host_migration()
	_test_codes()

	print("")
	print("%d/%d Prüfungen bestanden." % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_open() -> void:
	var lobby := Lobby.new()
	lobby.open(&"host", "Gastgeber", SeededRng.new(SEED))
	_check("Öffnen: Host ist Mitglied", lobby.player_count() == 1)
	_check("Öffnen: Host-Rolle gesetzt", lobby.host_id == &"host")
	_check("Öffnen: Code hat die richtige Länge",
		lobby.code.length() == Lobby.CODE_LENGTH)


func _test_join() -> void:
	var lobby := Lobby.new()
	lobby.open(&"host", "Host", SeededRng.new(SEED))
	_check("Beitritt: gültiger Beitritt akzeptiert", lobby.join(&"g1", "Gast 1") == "")
	_check("Beitritt: zwei Mitglieder", lobby.player_count() == 2)
	_check("Beitritt: doppelter Beitritt abgelehnt", lobby.join(&"g1", "Gast 1") != "")


func _test_capacity() -> void:
	var lobby := Lobby.new()
	lobby.open(&"host", "Host", SeededRng.new(SEED))
	lobby.join(&"g1", "G1")
	lobby.join(&"g2", "G2")
	lobby.join(&"g3", "G3")
	_check("Kapazität: volle Runde erreicht",
		lobby.player_count() == Lobby.MAX_PLAYERS)
	_check("Kapazität: weiterer Beitritt abgelehnt", lobby.join(&"g4", "G4") != "")


func _test_ready_and_start() -> void:
	var lobby := Lobby.new()
	lobby.open(&"host", "Host", SeededRng.new(SEED))
	lobby.join(&"g1", "G1")

	_check("Start: nicht ohne dass alle bereit sind", not lobby.can_start(&"host"))
	lobby.set_ready(&"host", true)
	lobby.set_ready(&"g1", true)
	_check("Start: möglich wenn alle bereit", lobby.can_start(&"host"))
	_check("Start: nur der Host darf starten", not lobby.can_start(&"g1"))

	# Einzelner Spieler reicht nicht für eine Online-Partie.
	var solo := Lobby.new()
	solo.open(&"host", "Host", SeededRng.new(SEED))
	solo.set_ready(&"host", true)
	_check("Start: ein Spieler allein reicht nicht", not solo.can_start(&"host"))


func _test_host_migration() -> void:
	var lobby := Lobby.new()
	lobby.open(&"host", "Host", SeededRng.new(SEED))
	lobby.join(&"g1", "G1")
	lobby.join(&"g2", "G2")
	lobby.leave(&"host")
	_check("Host-Migration: Rolle wandert weiter", lobby.host_id == &"g1")
	_check("Host-Migration: Host entfernt", lobby.player_count() == 2)


func _test_codes() -> void:
	# Determinismus: gleicher Seed -> gleicher Code.
	var c1 := Lobby.generate_code(SeededRng.new(SEED))
	var c2 := Lobby.generate_code(SeededRng.new(SEED))
	_check("Codes: gleicher Seed -> gleicher Code", c1 == c2)

	# Kein verwechselbares Zeichen (0, O, 1, I, L) im Code.
	var clean := true
	for i in 500:
		var code := Lobby.generate_code(SeededRng.new(SEED + i))
		for ch in code:
			if ch in ["0", "O", "1", "I", "L"]:
				clean = false
	_check("Codes: keine verwechselbaren Zeichen", clean)

	# Grobe Streuung: 500 Codes sollten nicht alle gleich sein.
	var distinct := {}
	for i in 500:
		distinct[Lobby.generate_code(SeededRng.new(SEED + i * 7))] = true
	_check("Codes: streuen breit (%d/500 verschieden)" % distinct.size(),
		distinct.size() > 400)


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  OK      %s" % label)
	else:
		_failures += 1
		print("  FEHLER  %s" % label)
