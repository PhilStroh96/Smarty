extends SceneTree

## Determinismus-Test für [SeededRng]. Läuft headless, ohne Editor:
##
## [codeblock]
## godot --headless --path . --script res://tests/determinism_test.gd
## [/codeblock]
##
## Exit-Code 0 = alles grün, 1 = Fehler. Damit CI-tauglich.
##
## Der ganze Netcode-Ansatz (PLAN.md §2.1) beruht darauf, dass Server und
## alle Clients aus demselben Seed dieselbe Aufgabenfolge erzeugen. Dieser
## Test ist die Absicherung dieser Annahme — er sollte bei jedem Commit
## laufen und muss auf jeder Zielplattform denselben Fingerprint liefern.

const SEED := 20260724

## Referenz-Fingerprint, erzeugt auf Windows / Godot 4.7.1-stable.
## Muss auf Android, iOS und Linux-Server identisch sein.
## Bei bewusster Änderung der RNG-Implementierung hier neu eintragen.
##
## Status: auf Windows bestätigt. Gegenprobe auf Android steht noch aus —
## sobald der erste Gerätebuild läuft, Fingerprint aus der Bootstrap-Szene
## ablesen und mit diesem Wert vergleichen.
const EXPECTED_FINGERPRINT := 4922622998030547710

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	print("Determinismus-Test — Godot %s auf %s" % [
		Engine.get_version_info()["string"], OS.get_name()
	])
	print("")

	_test_same_seed_same_sequence()
	_test_reset_reproducible()
	_test_fork_order_independent()
	_test_fork_distinct()
	_test_shuffle_deterministic()
	_test_shuffle_is_permutation()
	_test_float_range()
	_test_int_range_bounds()
	_test_pick_many_unique()

	var fp := _fingerprint()
	print("")
	print("Fingerprint: %d" % fp)
	if EXPECTED_FINGERPRINT != 0 and fp != EXPECTED_FINGERPRINT:
		_fail("Fingerprint weicht von der Referenz ab (erwartet %d)" % EXPECTED_FINGERPRINT)
	elif EXPECTED_FINGERPRINT == 0:
		print("  (Referenz noch nicht gesetzt — diesen Wert in")
		print("   EXPECTED_FINGERPRINT eintragen, sobald er auf Android bestätigt ist)")

	print("")
	print("%d/%d Prüfungen bestanden." % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------

func _test_same_seed_same_sequence() -> void:
	var a := SeededRng.new(SEED)
	var b := SeededRng.new(SEED)
	var sa: Array[int] = []
	var sb: Array[int] = []
	for i in 256:
		sa.append(a.next_int(0, 99999))
		sb.append(b.next_int(0, 99999))
	_check("Gleicher Seed erzeugt gleiche Folge", sa == sb)


func _test_reset_reproducible() -> void:
	var r := SeededRng.new(SEED)
	var first: Array[int] = []
	for i in 64:
		first.append(r.next_int(0, 9999))
	r.reset(SEED)
	var second: Array[int] = []
	for i in 64:
		second.append(r.next_int(0, 9999))
	_check("reset() stellt den Ausgangszustand her", first == second)


func _test_fork_order_independent() -> void:
	# fork(n) muss unabhängig davon sein, wie oft der Eltern-RNG
	# vorher gezogen wurde — sonst verschiebt eine Änderung an Aufgabe 2
	# sämtliche Aufgaben danach.
	var base := SeededRng.new(SEED)
	var before := base.fork(7).next_int(0, 999999)
	for i in 50:
		base.next_int(0, 100)
	var after := base.fork(7).next_int(0, 999999)
	_check("fork() ist reihenfolgeunabhängig", before == after)


func _test_fork_distinct() -> void:
	# Verschiedene Salts müssen verschiedene Folgen liefern, sonst
	# bekommen alle Aufgaben einer Runde denselben Inhalt.
	var base := SeededRng.new(SEED)
	var seen := {}
	var collisions := 0
	for i in 200:
		var v := base.fork(i).next_int(0, 999999)
		if seen.has(v):
			collisions += 1
		seen[v] = true
	_check("fork() mit verschiedenen Salts kollidiert kaum (%d/200)" % collisions,
		collisions <= 2)


func _test_shuffle_deterministic() -> void:
	var src := range(50)
	var a := SeededRng.new(SEED).shuffled(src)
	var b := SeededRng.new(SEED).shuffled(src)
	_check("shuffle() ist deterministisch", a == b)


func _test_shuffle_is_permutation() -> void:
	var src := range(100)
	var out := SeededRng.new(SEED).shuffled(src)
	var sorted_out := out.duplicate()
	sorted_out.sort()
	_check("shuffle() verliert und dupliziert keine Elemente",
		sorted_out == Array(src) and out.size() == 100)


func _test_float_range() -> void:
	var r := SeededRng.new(SEED)
	var ok := true
	for i in 10000:
		var v := r.next_float()
		if v < 0.0 or v >= 1.0:
			ok = false
			break
	_check("next_float() bleibt in [0, 1)", ok)


func _test_int_range_bounds() -> void:
	var r := SeededRng.new(SEED)
	var ok := true
	var hit_low := false
	var hit_high := false
	for i in 10000:
		var v := r.next_int(1, 6)
		if v < 1 or v > 6:
			ok = false
			break
		if v == 1:
			hit_low = true
		if v == 6:
			hit_high = true
	_check("next_int() respektiert beide Grenzen inklusive",
		ok and hit_low and hit_high)


func _test_pick_many_unique() -> void:
	var r := SeededRng.new(SEED)
	var picked := r.pick_many(range(20), 5)
	var unique := {}
	for v in picked:
		unique[v] = true
	_check("pick_many() zieht ohne Zurücklegen",
		picked.size() == 5 and unique.size() == 5)


func _fingerprint() -> int:
	var fp := 0
	var r := SeededRng.new(SEED)
	for i in 1000:
		fp = SeededRng.mix(fp, r.next_int(0, 65535))
	return fp


# ---------------------------------------------------------------------------

func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  OK      %s" % label)
	else:
		_failures += 1
		print("  FEHLER  %s" % label)


func _fail(msg: String) -> void:
	_checks += 1
	_failures += 1
	print("  FEHLER  %s" % msg)
