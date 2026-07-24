extends QuizMinigame

## Kurz gemerkt: Eine Reihe farbiger Symbole erscheint kurz und verschwindet
## wieder. Danach ist zu sagen, welches Symbol an einer bestimmten Stelle stand.
##
## Referenzimplementierung für Minispiele mit Einprägephase und gezeichneten
## Antworten. Drei Entscheidungen tragen das ganze Spiel:
##
## [br]1. [b]Die Form entscheidet, nicht die Farbe.[/b] Jede Form kommt in einer
##    Aufgabe höchstens einmal vor, die Farbe wird pro Aufgabe neu zugelost und
##    ist reine Zusatzstütze. Wer Farben schlecht unterscheidet, ist dadurch
##    nicht im Nachteil — und die Frage nach einer Stelle hat immer genau eine
##    Antwort.
## [br]2. [b]Die falschen Antworten stammen aus derselben Reihe.[/b] Kämen sie
##    von außerhalb, reichte "das habe ich gerade gesehen" als Strategie. So
##    muss man erinnern, [i]wo[/i] etwas stand, nicht nur [i]dass[/i] es kam.
## [br]3. [b]Nach der Merkzeit ist die Reihe weg.[/b] [method draw_task] fragt
##    [member in_study_phase] ab und zeichnet danach nur noch leere Felder mit
##    ihren Nummern. Bliebe die Reihe stehen, wäre die Aufgabe wertlos.

const OPTION_COUNT := 4

# --- Formen ---
#
# Fünf Grundformen plus das Kreuz. Das Kreuz ist nicht Zierde: Reihen gehen
# bis zu sechs Symbole, und nur mit sechs Formen bleibt jede Reihe frei von
# Wiederholungen. Ohne das wäre "welches Symbol stand an 4. Stelle" bei einer
# doppelt belegten Form mehrdeutig.
const FORM_KREIS := 0
const FORM_QUADRAT := 1
const FORM_DREIECK := 2
const FORM_RAUTE := 3
const FORM_STERN := 4
const FORM_KREUZ := 5
const FORM_ANZAHL := 6

## Farbtöne mit Kontrast auf dem dunklen Hintergrund (#1b1b2f). Bewusst nicht
## Rot gegen Grün als einziges Unterscheidungsmerkmal — die Form trägt ohnehin
## die ganze Information.
const FARBEN := [
	Color("#ffd369"),  # Bernstein
	Color("#4cc9f0"),  # Himmelblau
	Color("#f7768e"),  # Rosa
	Color("#b48ef0"),  # Violett
	Color("#5ee6a8"),  # Mint
	Color("#ff9e4a"),  # Orange
]

const ACCENT := Color("#ffd369")

## Symbole je Reihe, nach Schwierigkeitsstufe.
const REIHEN_LAENGE := [4, 5, 5, 6]

## Merkzeit in Sekunden, nach Schwierigkeitsstufe. Wird kürzer, während die
## Reihe länger wird — beides zusammen ergibt die Steigerung.
const MERKZEIT := [2.4, 2.2, 1.9, 1.6]


func _init() -> void:
	id = &"merken_paare"
	category = Category.MERKEN
	# Etwas mehr als die üblichen 60 s: Jede Aufgabe kostet vorweg rund zwei
	# Sekunden Merkzeit, in denen nicht gespielt werden kann.
	duration_sec = 70.0
	tutorial_text = "Merke dir die Symbolreihe und tippe an, welches an der gefragten Stelle stand."


func _make_task(index: int, task_rng: SeededRng) -> MinigameTask:
	var stufe := _stage_for(index)
	var laenge: int = REIHEN_LAENGE[stufe]

	# Formen ohne Zurücklegen ziehen — jede Stelle trägt eine eigene Form.
	var vorrat: Array[int] = []
	for f in FORM_ANZAHL:
		vorrat.append(f)
	task_rng.shuffle(vorrat)

	var reihe: Array[int] = []
	for i in laenge:
		reihe.append(vorrat[i])

	# Farbe je Form pro Aufgabe neu zulosen. Dieselbe Reihe sieht dadurch nie
	# zweimal gleich aus, ohne dass Farbe zum Unterscheidungsmerkmal wird.
	var farbwahl: Array[int] = []
	for c in FARBEN.size():
		farbwahl.append(c)
	task_rng.shuffle(farbwahl)
	var farben: Array[int] = []
	for f in FORM_ANZAHL:
		farben.append(farbwahl[f % farbwahl.size()])

	var stelle := _pick_position(stufe, laenge, task_rng)
	var loesung: int = reihe[stelle]
	var kandidaten := _build_candidates(reihe, loesung, task_rng)

	var task := MinigameTask.new("Welches Symbol war an %d. Stelle?" % (stelle + 1))
	task.option_count = OPTION_COUNT
	task.correct = kandidaten.find(loesung)
	task.study_seconds = MERKZEIT[stufe]
	task.study_prompt = "Merken!"
	task.draw_data = {
		"reihe": reihe,
		"farben": farben,
		"stelle": stelle,
		"kandidaten": kandidaten,
	}
	return task


## 0 = kurze Reihe mit viel Zeit, 3 = sechs Symbole in 1,6 Sekunden.
func _stage_for(index: int) -> int:
	var base := index / 5
	# difficulty verschiebt den Einstieg, damit derselbe Code für einen
	# leichten Trainingsmodus und für eine harte Partie taugt.
	return clampi(base + int(difficulty * 2.0), 0, 3)


## Wählt die gefragte Stelle (0-basiert).
##
## Anfang und Ende einer Reihe haften am besten. Auf der leichtesten Stufe wird
## deshalb meist am Rand gefragt, später überall — sonst ist schon der Einstieg
## für Ungeübte eine Wand.
func _pick_position(stufe: int, laenge: int, r: SeededRng) -> int:
	if stufe == 0 and r.chance(0.7):
		return 0 if r.chance(0.5) else laenge - 1
	return r.next_int(0, laenge - 1)


## Baut vier verschiedene Kandidaten: die Lösung plus drei Ablenker.
##
## Die Ablenker kommen zuerst aus der Reihe selbst. Damit ist "kam das vor?"
## als Abkürzung wertlos und es zählt nur noch die Position.
func _build_candidates(reihe: Array[int], loesung: int, r: SeededRng) -> Array[int]:
	var kandidaten: Array[int] = [loesung]

	var aus_reihe: Array[int] = []
	for f in reihe:
		if f != loesung and not aus_reihe.has(f):
			aus_reihe.append(f)
	r.shuffle(aus_reihe)
	for f in aus_reihe:
		if kandidaten.size() >= OPTION_COUNT:
			break
		kandidaten.append(f)

	# Notnagel für sehr kurze Reihen: dann fehlende Ablenker von außerhalb
	# nachlegen. Bei den aktuellen Reihenlängen greift das nicht.
	if kandidaten.size() < OPTION_COUNT:
		var rest: Array[int] = []
		for f in FORM_ANZAHL:
			if not kandidaten.has(f):
				rest.append(f)
		r.shuffle(rest)
		for f in rest:
			if kandidaten.size() >= OPTION_COUNT:
				break
			kandidaten.append(f)

	r.shuffle(kandidaten)
	return kandidaten


# ---------------------------------------------------------------------------
# Darstellung
# ---------------------------------------------------------------------------

func is_graphical() -> bool:
	return true


## Zeichnet die Reihe — aber nur, solange die Merkzeit läuft.
##
## Danach bleiben leere, nummerierte Felder stehen. Die machen sichtbar, welche
## Stelle gemeint ist, ohne irgendetwas zu verraten.
func draw_task(canvas: Control, task: MinigameTask) -> void:
	var flaeche := canvas.size
	if flaeche.x < 1.0 or flaeche.y < 1.0:
		return

	var reihe: Array = task.draw_data.get("reihe", [])
	if reihe.is_empty():
		return
	var farben: Array = task.draw_data.get("farben", [])
	var stelle: int = task.draw_data.get("stelle", 0)

	var schrift := canvas.get_theme_default_font()
	var kopf_groesse := int(clampf(flaeche.y * 0.11, 18.0, 46.0))
	var kopf := task.study_prompt if in_study_phase else task.prompt
	if schrift != null and kopf != "":
		canvas.draw_string(schrift, Vector2(0.0, flaeche.y * 0.17), kopf,
			HORIZONTAL_ALIGNMENT_CENTER, flaeche.x, kopf_groesse,
			ACCENT if in_study_phase else Color.WHITE)

	# Alles relativ zur Fläche: Die Ansicht bestimmt die Größe, nicht das Spiel.
	var feld_breite := flaeche.x / float(reihe.size())
	var mitte_y := flaeche.y * 0.52
	var radius := minf(feld_breite * 0.32, flaeche.y * 0.18)
	var nr_groesse := int(clampf(radius * 0.55, 13.0, 32.0))

	for i in reihe.size():
		var mitte := Vector2(feld_breite * (float(i) + 0.5), mitte_y)
		var form := int(reihe[i])
		if in_study_phase:
			_draw_symbol(canvas, form, _farbe_fuer(farben, form), mitte, radius)
		else:
			_draw_slot(canvas, mitte, radius, i == stelle, schrift)

		if schrift != null:
			var betont := (not in_study_phase) and i == stelle
			canvas.draw_string(schrift, Vector2(mitte.x - feld_breite * 0.5,
					mitte_y + radius + float(nr_groesse) * 1.25),
				"%d." % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, feld_breite,
				nr_groesse, ACCENT if betont else Color(1.0, 1.0, 1.0, 0.45))


## Zeichnet einen der vier Antwortkandidaten.
func draw_option(canvas: Control, task: MinigameTask, option: int) -> void:
	var flaeche := canvas.size
	if flaeche.x < 1.0 or flaeche.y < 1.0:
		return

	var kandidaten: Array = task.draw_data.get("kandidaten", [])
	if option < 0 or option >= kandidaten.size():
		return

	var farben: Array = task.draw_data.get("farben", [])
	var form := int(kandidaten[option])
	var radius := minf(flaeche.x, flaeche.y) * 0.30
	_draw_symbol(canvas, form, _farbe_fuer(farben, form), flaeche * 0.5, radius)


## Leeres Feld für eine Stelle, deren Symbol nicht mehr zu sehen ist.
func _draw_slot(canvas: Control, mitte: Vector2, radius: float, betont: bool,
		schrift: Font) -> void:
	var feld := Rect2(mitte - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	canvas.draw_rect(feld, Color(1.0, 1.0, 1.0, 0.06), true)
	canvas.draw_rect(feld, ACCENT if betont else Color(1.0, 1.0, 1.0, 0.22), false,
		maxf(2.0, radius * (0.11 if betont else 0.05)))
	if betont and schrift != null:
		var groesse := int(maxf(16.0, radius * 1.1))
		canvas.draw_string(schrift, Vector2(mitte.x - radius, mitte.y + radius * 0.38),
			"?", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, groesse, ACCENT)


## Zeichnet ein Symbol. [param radius] ist der halbe Platzbedarf; die Formen
## sind darin so skaliert, dass sie optisch gleich groß wirken.
func _draw_symbol(canvas: Control, form: int, farbe: Color, mitte: Vector2,
		radius: float) -> void:
	match form:
		FORM_KREIS:
			canvas.draw_circle(mitte, radius, farbe)
		FORM_QUADRAT:
			var s := radius * 0.86
			canvas.draw_rect(Rect2(mitte - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), farbe, true)
		FORM_DREIECK:
			canvas.draw_colored_polygon(_dreieck(mitte, radius * 1.14), farbe)
		FORM_RAUTE:
			canvas.draw_colored_polygon(_raute(mitte, radius * 1.12), farbe)
		FORM_STERN:
			canvas.draw_colored_polygon(_stern(mitte, radius * 1.15, radius * 0.48), farbe)
		FORM_KREUZ:
			canvas.draw_colored_polygon(_kreuz(mitte, radius * 1.02, radius * 0.34), farbe)
		_:
			canvas.draw_circle(mitte, radius, farbe)


func _farbe_fuer(farben: Array, form: int) -> Color:
	if form < 0 or form >= farben.size():
		return Color.WHITE
	return FARBEN[int(farben[form]) % FARBEN.size()]


func _dreieck(mitte: Vector2, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 3:
		var winkel := -PI / 2.0 + float(i) * TAU / 3.0
		p.append(mitte + Vector2(cos(winkel), sin(winkel)) * r)
	return p


## Bewusst höher als breit — so ist die Raute auch bei flüchtigem Blick nicht
## mit dem Quadrat zu verwechseln.
func _raute(mitte: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		mitte + Vector2(0.0, -r),
		mitte + Vector2(r * 0.66, 0.0),
		mitte + Vector2(0.0, r),
		mitte + Vector2(-r * 0.66, 0.0),
	])


func _stern(mitte: Vector2, aussen: float, innen: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 10:
		var winkel := -PI / 2.0 + float(i) * PI / 5.0
		var r := aussen if i % 2 == 0 else innen
		p.append(mitte + Vector2(cos(winkel), sin(winkel)) * r)
	return p


## Gleichschenkliges Kreuz. [param arm] ist die Armlänge, [param dicke] die
## halbe Armbreite.
func _kreuz(mitte: Vector2, arm: float, dicke: float) -> PackedVector2Array:
	return PackedVector2Array([
		mitte + Vector2(-dicke, -arm),
		mitte + Vector2(dicke, -arm),
		mitte + Vector2(dicke, -dicke),
		mitte + Vector2(arm, -dicke),
		mitte + Vector2(arm, dicke),
		mitte + Vector2(dicke, dicke),
		mitte + Vector2(dicke, arm),
		mitte + Vector2(-dicke, arm),
		mitte + Vector2(-dicke, dicke),
		mitte + Vector2(-arm, dicke),
		mitte + Vector2(-arm, -dicke),
		mitte + Vector2(-dicke, -dicke),
	])
