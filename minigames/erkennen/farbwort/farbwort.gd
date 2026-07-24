extends QuizMinigame

## Farbe oder Wort: Ein Farbwort steht in einer anderen Farbe da.
##
## Der Stroop-Effekt. Lesen läuft automatisch ab, das Benennen einer Farbe
## nicht — wer "ROT" in Blau sieht, muss die schon fertige Leseantwort aktiv
## unterdrücken. Genau diese Unterdrückung ist die gemessene Leistung, nicht
## das Erkennen der Farbe an sich.
##
## Daraus folgen zwei Entwurfsentscheidungen:
## [br]1. Wort und Schriftfarbe stimmen nur selten überein — bis Stufe 2 in
##    rund jeder fünften Aufgabe, ab Stufe 3 nur noch in rund jeder achten.
##    Ohne Konflikt gibt es nichts zu unterdrücken; ganz ohne
##    Übereinstimmung könnte man dagegen blind die gelesene Farbe ausschließen
##    und käme auf drei statt vier Möglichkeiten.
## [br]2. Das gelesene Wort ist immer eine der Antworten. Es ist der
##    naheliegende Fehler — ohne diese Falle wäre die Aufgabe nur eine
##    Farberkennung.
##
## Grafisch, weil farbiger Text nötig ist: Die Aufgabe wird in
## [method draw_task] gezeichnet. Die Antworten bleiben Text auf den Knöpfen,
## damit man Farbnamen liest und nicht Farbflächen vergleicht — sonst würde
## das Spiel den Konflikt wieder auflösen.

const OPTION_COUNT := 4

## Grundgröße der Schrift. Wird in [method draw_task] verkleinert, falls die
## Platte sonst breiter oder höher wäre als die Zeichenfläche.
const SCHRIFT_GROESSE := 110

## Untergrenze beim Verkleinern. Darunter ist das Wort auf einem Telefon
## nicht mehr sicher lesbar — dann lieber überstehen lassen als unlesbar.
const MIN_SCHRIFT := 28

## Maße der Platte hinter dem Wort, in Schriftgrößen: Rand links und rechts,
## Gesamthöhe. Sie gehen in die Größenberechnung ein, damit begrenzt wird,
## was am Ende wirklich auf der Fläche liegt.
const PLATTE_RAND := 0.3
const PLATTE_HOEHE := 1.28

## Farbnamen in der Reihenfolge des Farbkreises. Die Reihenfolge ist
## bedeutungstragend: Nachbarn im Array sind auch optisch benachbart, daraus
## zieht [method _nachbarn] die schweren Ablenker.
const FARB_NAMEN: Array[String] = [
	"ROT", "ORANGE", "GELB", "GRÜN", "TÜRKIS", "BLAU", "LILA",
]

## Passende Farbwerte, hell genug für den dunklen Hintergrund (#1b1b2f).
##
## Die Werte unterscheiden sich bewusst nicht nur im Farbton, sondern auch
## deutlich in der Helligkeit — ROT ist merklich dunkler als GRÜN, GELB ist
## das hellste. Wer Rot und Grün schlecht trennt, hat damit ein zweites,
## unabhängiges Merkmal. Ein Formmerkmal ist hier nicht möglich: Die Farbe
## ist die Antwort, jeder zusätzliche Hinweis darauf würde die Aufgabe
## verschenken.
const FARB_HEX: Array[String] = [
	"#f4443c", "#ff8c1a", "#ffe14d", "#3fd45f", "#22d3ee", "#3d7dff", "#c084fc",
]

## Fünf weit auseinanderliegende Farben für den Einstieg.
const BASIS_PALETTE: Array[int] = [0, 2, 3, 5, 6]

## Alle sieben, inklusive der Zwischentöne ORANGE und TÜRKIS.
const VOLLE_PALETTE: Array[int] = [0, 1, 2, 3, 4, 5, 6]

## Dunkle Platte hinter dem Wort. Der Aufgabenbereich liegt in einem
## PanelContainer, dessen Hintergrund je nach Thema heller ausfallen kann —
## die Platte macht den Kontrast unabhängig davon.
const PLATTE_HEX := "#12121e"


func _init() -> void:
	id = &"erkennen_farbwort"
	category = Category.ERKENNEN
	duration_sec = 50.0
	# Getippt wird ein Farbname auf einem Knopf, keine Farbfläche. Die Regel
	# sagt das ausdrücklich — in genau diesem Spiel darf sie Farbe und Wort
	# nicht selbst wieder vermischen.
	tutorial_text = "Tippe den Namen der Schriftfarbe an — nicht das Wort, das du liest."


func _make_task(index: int, task_rng: SeededRng) -> MinigameTask:
	var stufe := _stage_for(index)
	var palette := _palette_for(stufe)

	# Erst die Schriftfarbe — sie ist die richtige Antwort.
	var tinte := int(task_rng.pick(palette))

	# Dann das Wort. Konflikt ist der Normalfall, Übereinstimmung die
	# Ausnahme (siehe Klassenkommentar).
	var wort := tinte
	if not task_rng.chance(_kongruenz_chance(stufe)):
		var andere := palette.duplicate()
		andere.erase(tinte)
		wort = int(task_rng.pick(andere))

	var namen := _build_options(stufe, tinte, wort, palette, task_rng)

	# Als prompt steht das gelesene Wort. Sichtbar ist es nicht — grafische
	# Spiele blenden das Textfeld aus —, aber es beschreibt die Aufgabe
	# eindeutig und macht sie damit vergleichbar und protokollierbar.
	var task := MinigameTask.new(FARB_NAMEN[wort], namen, namen.find(FARB_NAMEN[tinte]))
	task.draw_data = {
		"wort": FARB_NAMEN[wort],
		"tinte": FARB_NAMEN[tinte],
		"tinte_hex": FARB_HEX[tinte],
		"kongruent": wort == tinte,
	}
	return task


## 0 = klare Farben, 1 = feinere Farbtöne, 2 = Nachbarfarbe als Ablenker,
## 3 = zusätzlich kaum noch Aufgaben ohne Konflikt.
func _stage_for(index: int) -> int:
	var basis := index / 8
	# difficulty verschiebt den Einstieg, damit derselbe Code für eine lockere
	# und für eine harte Partie taugt.
	return clampi(basis + int(difficulty * 2.0), 0, 3)


func _palette_for(stufe: int) -> Array[int]:
	# Ab Stufe 1 kommen ORANGE und TÜRKIS dazu. Beide liegen zwischen zwei
	# Grundfarben, das Benennen dauert dadurch spürbar länger.
	return BASIS_PALETTE if stufe <= 0 else VOLLE_PALETTE


## Wie oft Wort und Schriftfarbe übereinstimmen dürfen.
func _kongruenz_chance(stufe: int) -> float:
	return 0.2 if stufe < 3 else 0.12


## Vier verschiedene Farbnamen: die Schriftfarbe, das gelesene Wort und
## Auffüller.
func _build_options(
	stufe: int, tinte: int, wort: int, palette: Array[int], r: SeededRng
) -> Array[String]:
	var namen: Array[String] = [FARB_NAMEN[tinte]]

	# Die Falle: Wer nur liest, tippt hier. Bei Übereinstimmung fällt sie
	# weg, dann rückt ein Auffüller nach.
	if wort != tinte:
		namen.append(FARB_NAMEN[wort])

	for f in _fueller_reihenfolge(stufe, tinte, wort, palette, r):
		if namen.size() >= OPTION_COUNT:
			break
		var n := FARB_NAMEN[f]
		# Doppelte Farbnamen wären mehrdeutig statt schwer.
		if not namen.has(n):
			namen.append(n)

	r.shuffle(namen)
	return namen


## Reihenfolge, in der die übrigen Farben als Ablenker nachrücken.
##
## Maßgeblich sind die Nachbarn der SCHRIFTFARBE, nicht die des gelesenen
## Wortes: Zu benennen ist die Farbe, also muss die Verwechslungsgefahr auch
## dort sitzen. Steht "BLAU" in Rot, ist ORANGE der schwere Ablenker, nicht
## TÜRKIS.
##
## Ab Stufe 2 rückt so eine Nachbarfarbe nach vorn und ist damit sicher unter
## den Antworten — ein grober Farbeindruck reicht dann nicht mehr, der Farbton
## muss genau getroffen werden.
##
## Darunter passiert bewusst das Gegenteil: Nachbarfarben rutschen ans Ende.
## Ohne das läge auch auf den unteren Stufen rein zufällig in vier von fünf
## Aufgaben eine Nachbarfarbe dabei — der Schritt auf Stufe 2 wäre dann nur
## auf dem Papier einer.
func _fueller_reihenfolge(
	stufe: int, tinte: int, wort: int, palette: Array[int], r: SeededRng
) -> Array[int]:
	var rest: Array[int] = []
	for f in palette:
		if f != tinte and f != wort:
			rest.append(f)
	r.shuffle(rest)

	var nachbarn := _nachbarn(tinte)

	if stufe >= 2:
		r.shuffle(nachbarn)
		for n in nachbarn:
			if rest.has(n):
				rest.erase(n)
				rest.insert(0, n)
				break
		return rest

	# Weit entfernte Farben zuerst. Die Nachbarn bleiben hinten und kommen
	# nur zum Zug, wenn sonst nicht genug Farben da sind — bei fünf Farben
	# in der Grundpalette kann das vorkommen und ist dann kein Fehler,
	# sondern die einzige Möglichkeit, auf vier Antworten zu kommen.
	var fern: Array[int] = []
	var nah: Array[int] = []
	for f in rest:
		if nachbarn.has(f):
			nah.append(f)
		else:
			fern.append(f)
	fern.append_array(nah)
	return fern


## Die beiden im Farbkreis angrenzenden Farben.
func _nachbarn(farbe: int) -> Array[int]:
	var anzahl := FARB_NAMEN.size()
	return [(farbe + anzahl - 1) % anzahl, (farbe + 1) % anzahl]


# ---------------------------------------------------------------------------
# Darstellung
# ---------------------------------------------------------------------------

## Die Aufgabe braucht farbigen Text und wird deshalb gezeichnet.
func is_graphical() -> bool:
	return true


## Zeichnet das Farbwort mittig in seiner Schriftfarbe.
##
## Alle Angaben stammen aus [member MinigameTask.draw_data] und damit aus dem
## Seed. Hier wird nicht gewürfelt — sonst sähe jedes Neuzeichnen anders aus.
func draw_task(canvas: Control, task: MinigameTask) -> void:
	var wort: String = task.draw_data.get("wort", "")
	if wort.is_empty():
		return

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var flaeche := canvas.size
	if flaeche.x <= 0.0 or flaeche.y <= 0.0:
		return

	var groesse := SCHRIFT_GROESSE

	# Relativ zur Fläche verkleinern, statt mit festen Pixeln zu rechnen:
	# "ORANGE" ist doppelt so breit wie "ROT", und die logische Fläche ist
	# geräteabhängig (stretch aspect="expand"). Begrenzt wird dabei immer die
	# PLATTE, nicht nur der Text — sonst passt zwar das Wort, der Rand ragt
	# aber über die Fläche hinaus.
	var max_hoehe := flaeche.y * 0.86
	if float(groesse) * PLATTE_HOEHE > max_hoehe:
		groesse = maxi(MIN_SCHRIFT, int(max_hoehe / PLATTE_HOEHE))

	var max_breite := flaeche.x * 0.86
	var breite := font.get_string_size(wort, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
	# Zwei feste Durchgänge: der erste rechnet die Größe proportional herunter,
	# der zweite fängt die Abrundung ab. Feste Zahl statt Schleifenbedingung,
	# damit die Methode garantiert terminiert.
	for _i in 2:
		var voll := breite + float(groesse) * PLATTE_RAND * 2.0
		if voll <= max_breite or voll <= 0.0:
			break
		groesse = maxi(MIN_SCHRIFT, int(float(groesse) * max_breite / voll))
		breite = font.get_string_size(wort, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x

	var mitte := flaeche * 0.5
	# draw_string setzt an der Grundlinie an, nicht an der Oberkante — der
	# Zuschlag rückt das Wort optisch in die Mitte.
	var basis := Vector2(mitte.x - breite * 0.5, mitte.y + groesse * 0.34)

	var rand := float(groesse) * PLATTE_RAND
	canvas.draw_rect(Rect2(
		basis.x - rand,
		mitte.y - float(groesse) * PLATTE_HOEHE * 0.5,
		breite + rand * 2.0,
		float(groesse) * PLATTE_HOEHE
	), Color(PLATTE_HEX))

	var hex: String = task.draw_data.get("tinte_hex", "#ffffff")
	canvas.draw_string(font, basis, wort, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, Color(hex))


## Die Antworten sind Farbnamen als Knopfbeschriftung aus
## [member MinigameTask.options] — hier gibt es nichts zu zeichnen. Würde man
## sie als Farbflächen zeigen, verschwände der Konflikt zwischen Lesen und
## Sehen, und damit die ganze Aufgabe.
func draw_option(_canvas: Control, _task: MinigameTask, _option: int) -> void:
	pass
