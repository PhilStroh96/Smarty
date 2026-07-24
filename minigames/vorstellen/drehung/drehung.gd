extends QuizMinigame

## Räumliches Vorstellen: Oben eine Form, unten vier — welche ist dieselbe,
## nur gedreht?
##
## Gemessen wird mentale Rotation. Damit die Aufgabe überhaupt lösbar ist,
## muss die Grundform [i]voll asymmetrisch[/i] sein. Zwei Bedingungen:
## [br]1. Ihre vier Drehungen müssen sich alle voneinander unterscheiden.
##    Sonst sähe die "gedrehte" Antwort genauso aus wie die Vorlage und die
##    Aufgabe wäre geschenkt.
## [br]2. Ihr Spiegelbild darf mit keiner ihrer Drehungen übereinstimmen
##    (Chiralität). Sonst wäre ein gespiegelter Ablenker in Wahrheit
##    ebenfalls richtig — die Aufgabe hätte zwei Lösungen und wäre unfair.
## Beides prüft [method _ist_voll_asymmetrisch] aktiv nach; Formen, die
## durchfallen, werden verworfen und neu gewürfelt.
##
## Die Ablenker sind Spiegelbilder (in beliebiger Drehung) und Formen mit
## einem versetzten Segment. Jeder Ablenker wird gegen alle vier Drehungen
## der Vorlage geprüft und aussortiert, wenn er zufällig doch passt.
##
## Höchstens zwei der drei Ablenker sind Spiegelbilder — siehe
## [method _spiegel_anzahl_fuer]. Bei dreien wäre die Aufgabe ohne einen Blick
## auf die Vorlage lösbar, und gemessen würde etwas anderes als gewollt.
##
## Alle Formen entstehen in [method _make_task] aus [param task_rng] und
## liegen als Zellenlisten in [member MinigameTask.draw_data]. In den
## Zeichenmethoden wird nicht gewürfelt — sonst flackerte jedes Bild.

const OPTION_COUNT := 4

## Größte erlaubte Kantenlänge des umschließenden Rechtecks in Zellen.
##
## Begrenzt die Formen auf kompakte Klötze: Ein langer Strich wäre auf einem
## Antwortfeld von 150 px Höhe nur noch ein Strich.
const MAX_GITTER := 4

## Reihenfolge: oben, rechts, unten, links. Wird sowohl für die
## Nachbarschaftsprüfung als auch fürs Zeichnen der Kanten benutzt.
const NACHBARN: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

## Notfallform, falls das Würfeln keine voll asymmetrische Form liefert.
## Das L-Pentomino erfüllt beide Bedingungen und ist der Fallschirm, damit
## [method _make_task] nie ohne Ergebnis dasteht.
const NOTFALL: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3),
]

## So oft wird eine Form neu gewürfelt, bevor [constant NOTFALL] greift.
const VERSUCHE := 200

const HINTERGRUND := Color("#1b1b2f")
## Warmes Gelb für die Vorlage, kühles Hellblau für die Antworten: Die
## Farbe trennt Frage von Auswahl, niemals richtig von falsch. Alle vier
## Antwortfelder sind identisch eingefärbt — die Entscheidung fällt
## ausschließlich über die Form, damit Farbenblindheit keine Rolle spielt.
const FARBE_AUFGABE := Color("#ffd369")
const FARBE_OPTION := Color("#8ecae6")


func _init() -> void:
	id = &"vorstellen_drehung"
	category = Category.VORSTELLEN
	duration_sec = 60.0
	tutorial_text = "Finde unten dieselbe Form wie oben, nur gedreht – gespiegelte sind falsch."


func _make_task(index: int, task_rng: SeededRng) -> MinigameTask:
	var stufe := _stage_for(index)
	var basis := _erzeuge_form(_zellen_fuer(stufe), task_rng)

	# Die vier Drehungen der Vorlage sind tabu für jeden Ablenker: Was mit
	# einer davon übereinstimmt, wäre eine zweite richtige Antwort.
	var drehungen := {}
	for k in 4:
		drehungen[_schluessel(_rotiere(basis, k))] = true

	var gesehen := drehungen.duplicate()
	var spiegel_topf := _spiegel_varianten(basis, gesehen)
	var versetzt_topf := _versatz_varianten(basis, gesehen)
	task_rng.shuffle(spiegel_topf)
	task_rng.shuffle(versetzt_topf)

	# Antwort 0 ist immer die richtige — die Vorlage um 90, 180 oder 270
	# Grad gedreht. Gemischt wird erst ganz zum Schluss.
	var formen: Array = [_rotiere(basis, task_rng.next_int(1, 3))]
	var spiegel_anzahl := _spiegel_anzahl_fuer(stufe)
	for i in OPTION_COUNT - 1:
		var nimm_spiegel := i < spiegel_anzahl
		# Ist der gewünschte Topf leer, wird aus dem anderen genommen. So
		# stehen am Ende garantiert vier verschiedene Formen bereit.
		#
		# Nur dieser Notausgang könnte den Deckel aus
		# [method _spiegel_anzahl_fuer] überschreiten. Dafür müsste der
		# Versatz-Topf leer sein — bei fünf bis sieben Zellen liefert die
		# vollständige Aufzählung dort immer Dutzende Formen, die Sperrliste
		# hat nur acht Einträge. Vier Antwortfelder wiegen im Zweifel schwerer
		# als der Deckel.
		var topf: Array = spiegel_topf if nimm_spiegel else versetzt_topf
		if topf.is_empty():
			topf = versetzt_topf if nimm_spiegel else spiegel_topf
		if topf.is_empty():
			break
		formen.append(topf.pop_back())

	# Sollte wider Erwarten etwas fehlen: mit Drehungen des Spiegelbilds
	# auffüllen. Die sind immer verfügbar und nie versehentlich richtig.
	var reserve := 0
	while formen.size() < OPTION_COUNT:
		var f := _rotiere(_spiegle(basis), reserve % 4)
		reserve += 1
		if not _enthaelt(formen, f):
			formen.append(f)
		if reserve > 8:
			break

	# Mischen über die Indizes statt über die Formen: So bleibt bekannt,
	# wohin Antwort 0 gewandert ist.
	var reihenfolge: Array[int] = []
	for i in formen.size():
		reihenfolge.append(i)
	task_rng.shuffle(reihenfolge)

	var gemischt: Array = []
	var richtig := 0
	for platz in reihenfolge.size():
		gemischt.append(formen[reihenfolge[platz]])
		if reihenfolge[platz] == 0:
			richtig = platz

	# Größtes umschließendes Rechteck über Vorlage und alle Antworten. Damit
	# zeichnen alle fünf Felder mit demselben Bezugsgitter. Würde jede Form für
	# sich auf ihr Feld skaliert, erschiene ein flacher Klotz größer als ein
	# hoher — ein Größenunterschied, den es in der Aufgabe nicht gibt und
	# der das Drehen im Kopf zusätzlich erschwert.
	var bezug := Vector2i.ZERO
	for f in gemischt + [basis]:
		for z in f:
			bezug.x = maxi(bezug.x, z.x + 1)
			bezug.y = maxi(bezug.y, z.y + 1)

	var gepackt: Array = []
	for f in gemischt:
		gepackt.append(_packe(f))

	# Der Fragetext wird bei grafischen Aufgaben nicht angezeigt (die Ansicht
	# blendet ihn aus). Er trägt hier eine Kurzkennung der Form: Damit ist
	# jede Aufgabe von außen unterscheidbar — der Server kann sie ohne
	# Zeichnen nachrechnen und der Test erkennt, dass zwei Seeds wirklich
	# verschiedene Aufgaben liefern.
	var task := MinigameTask.new("gedreht %s" % _schluessel(basis), [], richtig)
	task.option_count = gemischt.size()
	task.draw_data = {
		"aufgabe": _packe(basis),
		"optionen": gepackt,
		"gitter": PackedInt32Array([bezug.x, bezug.y]),
	}
	return task


func is_graphical() -> bool:
	return true


## 0 = fünf Zellen mit nur einem Spiegel-Ablenker, 3 = sieben Zellen mit
## zwei Spiegel-Ablenkern.
func _stage_for(index: int) -> int:
	var base := index / 5
	# difficulty verschiebt den Einstieg, damit derselbe Code für einen
	# leichten Trainingsmodus und für eine harte Partie taugt.
	return clampi(base + int(difficulty * 2.0), 0, 3)


## Zellen je Stufe.
##
## Die oberste Stufe hat eine Zelle mehr als die vorletzte. Ohne das wären
## beide gleich schwer, seit die Spiegel-Ablenker bei zwei gedeckelt sind
## (siehe [method _spiegel_anzahl_fuer]) — und mehr Zellen sind der ehrlichste
## Weg, das Drehen im Kopf zu erschweren: Die Form bleibt durch
## [constant MAX_GITTER] gleich groß auf dem Feld, nur unübersichtlicher.
func _zellen_fuer(stufe: int) -> int:
	return [5, 5, 6, 7][clampi(stufe, 0, 3)]


## Wie viele der drei Ablenker Spiegelbilder sind.
##
## Spiegelbilder sind die harten Ablenker — sie lassen sich nur durch echtes
## Drehen im Kopf ausschließen. Versetzte Segmente sind leichter zu sehen und
## halten die frühen Aufgaben spielbar.
##
## [b]Höchstens zwei[/b], niemals drei: Alle Drehungen des Spiegelbilds sind
## untereinander durch Drehen ineinander überführbar. Bei drei Spiegel-
## Ablenkern sähen also drei der vier Antworten wie [i]dieselbe[/i] Form in
## verschiedenen Lagen aus, und die vierte wäre der Ausreißer. Die richtige
## Antwort ließe sich dann allein aus den Antwortfeldern ablesen, ohne die
## Vorlage auch nur anzusehen — gemessen würde nicht mehr das Drehen zur
## Vorlage, sondern "finde den Andersartigen". Mit höchstens zwei Spiegeln
## bleiben immer zwei Einzelgänger übrig und die Vorlage entscheidet.
func _spiegel_anzahl_fuer(stufe: int) -> int:
	# Der Deckel steht bewusst hier und nicht nur in der Tabelle: Er muss
	# auch halten, wenn die Stufen später umgestellt werden.
	return mini([1, 2, 2, 2][clampi(stufe, 0, 3)], OPTION_COUNT - 2)


# ---------------------------------------------------------------------------
# Formerzeugung
# ---------------------------------------------------------------------------

## Würfelt eine zusammenhängende, voll asymmetrische Form aus [param anzahl]
## Zellen.
func _erzeuge_form(anzahl: int, r: SeededRng) -> Array[Vector2i]:
	for versuch in VERSUCHE:
		var kandidat := _normiere(_wachse(anzahl, r))
		if kandidat.size() != anzahl:
			continue
		if _groesste_kante(kandidat) > MAX_GITTER:
			continue
		if _ist_voll_asymmetrisch(kandidat):
			return kandidat
	return _normiere(NOTFALL)


## Lässt eine Form Zelle für Zelle wachsen: Aus allen freien Nachbarfeldern
## wird eines gezogen und angehängt.
func _wachse(anzahl: int, r: SeededRng) -> Array[Vector2i]:
	var zellen: Array[Vector2i] = [Vector2i.ZERO]
	while zellen.size() < anzahl:
		var belegt := {}
		for z in zellen:
			belegt[z] = true
		var frei: Array[Vector2i] = []
		for z in zellen:
			for d in NACHBARN:
				var n: Vector2i = z + d
				if not belegt.has(n) and not frei.has(n):
					frei.append(n)
		if frei.is_empty():
			break
		var gewaehlt: Vector2i = r.pick(frei)
		zellen.append(gewaehlt)
	return zellen


## True, wenn die Form vier verschiedene Drehungen hat und ihr Spiegelbild
## mit keiner davon übereinstimmt.
func _ist_voll_asymmetrisch(zellen: Array[Vector2i]) -> bool:
	var drehungen := {}
	for k in 4:
		drehungen[_schluessel(_rotiere(zellen, k))] = true
	if drehungen.size() != 4:
		return false
	for k in 4:
		if drehungen.has(_schluessel(_rotiere(_spiegle(zellen), k))):
			return false
	return true


## Alle Drehungen des Spiegelbilds, die noch nicht in [param gesehen] stehen.
func _spiegel_varianten(basis: Array[Vector2i], gesehen: Dictionary) -> Array:
	var out: Array = []
	var gespiegelt := _spiegle(basis)
	for k in 4:
		var f := _rotiere(gespiegelt, k)
		var s := _schluessel(f)
		if gesehen.has(s):
			continue
		gesehen[s] = true
		out.append(f)
	return out


## Alle Formen, bei denen genau ein Segment an eine andere Stelle gewandert
## ist — in allen vier Drehungen.
##
## Vollständig aufgezählt statt gewürfelt: Der Topf ist dann garantiert groß
## genug, und gemischt wird er anschließend mit [param task_rng].
func _versatz_varianten(basis: Array[Vector2i], gesehen: Dictionary) -> Array:
	var out: Array = []
	for i in basis.size():
		var rest: Array[Vector2i] = []
		for j in basis.size():
			if j != i:
				rest.append(basis[j])
		# Ein Segment darf nur weg, wenn der Rest zusammenhängend bleibt.
		if not _ist_zusammenhaengend(rest):
			continue
		var belegt := {}
		for z in rest:
			belegt[z] = true
		var ziele: Array[Vector2i] = []
		for z in rest:
			for d in NACHBARN:
				var n: Vector2i = z + d
				# Die alte Stelle ist tabu — sonst käme die Vorlage zurück.
				if belegt.has(n) or n == basis[i] or ziele.has(n):
					continue
				ziele.append(n)
		for ziel in ziele:
			var neu := rest.duplicate()
			neu.append(ziel)
			for k in 4:
				var f := _rotiere(neu, k)
				if _groesste_kante(f) > MAX_GITTER:
					continue
				var s := _schluessel(f)
				if gesehen.has(s):
					continue
				gesehen[s] = true
				out.append(f)
	return out


func _ist_zusammenhaengend(zellen: Array[Vector2i]) -> bool:
	if zellen.is_empty():
		return false
	var belegt := {}
	for z in zellen:
		belegt[z] = true
	var gesehen := {zellen[0]: true}
	var stapel: Array[Vector2i] = [zellen[0]]
	while not stapel.is_empty():
		var z: Vector2i = stapel.pop_back()
		for d in NACHBARN:
			var n: Vector2i = z + d
			if belegt.has(n) and not gesehen.has(n):
				gesehen[n] = true
				stapel.append(n)
	return gesehen.size() == zellen.size()


# ---------------------------------------------------------------------------
# Gitter-Rechnerei
# ---------------------------------------------------------------------------

## Dreht [param zellen] um [param viertel] mal 90 Grad im Uhrzeigersinn.
func _rotiere(zellen: Array[Vector2i], viertel: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in zellen:
		var p := z
		for i in posmod(viertel, 4):
			p = Vector2i(-p.y, p.x)
		out.append(p)
	return _normiere(out)


## Spiegelt [param zellen] an der senkrechten Achse.
func _spiegle(zellen: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in zellen:
		out.append(Vector2i(-z.x, z.y))
	return _normiere(out)


## Schiebt die Form in die linke obere Ecke und sortiert die Zellen.
##
## Erst dadurch sind zwei Formen vergleichbar: Gleiche Form heißt gleiche
## Liste, unabhängig davon, wo sie im Gitter entstanden ist.
func _normiere(zellen: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if zellen.is_empty():
		return out
	var min_x: int = zellen[0].x
	var min_y: int = zellen[0].y
	for z in zellen:
		min_x = mini(min_x, z.x)
		min_y = mini(min_y, z.y)
	# Sortieren über eine Zahlenkodierung statt über einen Vergleicher:
	# PackedInt32Array.sort() ist auf jeder Plattform identisch.
	var codes := PackedInt32Array()
	for z in zellen:
		codes.append((z.y - min_y) * 64 + (z.x - min_x))
	codes.sort()
	for c in codes:
		out.append(Vector2i(c % 64, c / 64))
	return out


## Kennung einer normierten Form. Gleiche Kennung heißt gleiche Form.
func _schluessel(zellen: Array[Vector2i]) -> String:
	var teile := PackedStringArray()
	for z in zellen:
		teile.append("%d.%d" % [z.x, z.y])
	return "-".join(teile)


func _enthaelt(formen: Array, form: Array[Vector2i]) -> bool:
	var s := _schluessel(form)
	for f in formen:
		if _schluessel(f) == s:
			return true
	return false


## Längere Seite des umschließenden Rechtecks, in Zellen.
func _groesste_kante(zellen: Array[Vector2i]) -> int:
	var breite := 0
	var hoehe := 0
	for z in zellen:
		breite = maxi(breite, z.x + 1)
		hoehe = maxi(hoehe, z.y + 1)
	return maxi(breite, hoehe)


func _packe(zellen: Array[Vector2i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for z in zellen:
		out.append(z.x)
		out.append(z.y)
	return out


func _entpacke(flach: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var i := 0
	while i + 1 < flach.size():
		out.append(Vector2i(flach[i], flach[i + 1]))
		i += 2
	return out


# ---------------------------------------------------------------------------
# Darstellung
# ---------------------------------------------------------------------------

## Wie viel der Fläche die Vorlage einnimmt.
##
## Deutlich kleiner als bei den Antworten: Die Aufgabenfläche ist um ein
## Vielfaches größer als ein Antwortfeld. Bei gleichem Anteil erschlüge die
## Vorlage die Auswahl optisch, und der Blickwechsel zwischen oben und unten
## würde unnötig anstrengend.
##
## Der Wert ist so gewählt, dass die Vorlage in der Zielauflösung noch
## ungefähr doppelt so große Zellen hat wie eine Antwort. Größere Unterschiede
## kosten echte Arbeit: Wer vergleichen will, muss dann [i]zusätzlich[/i] zum
## Drehen noch maßstäblich umrechnen — genau die Nebenanstrengung, die in
## einer Aufgabe zum räumlichen Vorstellen nichts zu suchen hat.
const ANTEIL_AUFGABE := 0.42

## Antworten dürfen ihr Feld fast ausfüllen — je größer die Form, desto
## leichter ist sie im Kopf zu drehen.
const ANTEIL_OPTION := 0.80


func draw_task(canvas: Control, task: MinigameTask) -> void:
	var flach: PackedInt32Array = task.draw_data.get("aufgabe", PackedInt32Array())
	# Dasselbe Bezugsgitter wie die Antworten: Sonst hinge die Zellengröße der
	# Vorlage daran, ob die Form gerade hoch oder breit liegt — eine liegende
	# Form käme doppelt so groß heraus wie eine stehende, obwohl es dieselbe
	# Form ist.
	_zeichne_form(canvas, flach, FARBE_AUFGABE, ANTEIL_AUFGABE, _bezug_von(task))


func draw_option(canvas: Control, task: MinigameTask, option: int) -> void:
	var liste: Array = task.draw_data.get("optionen", [])
	if option < 0 or option >= liste.size():
		return
	_zeichne_form(canvas, liste[option], FARBE_OPTION, ANTEIL_OPTION, _bezug_von(task))


## Das gemeinsame Bezugsgitter aus [member MinigameTask.draw_data].
func _bezug_von(task: MinigameTask) -> Vector2i:
	var gitter: PackedInt32Array = task.draw_data.get("gitter", PackedInt32Array())
	if gitter.size() < 2:
		return Vector2i.ZERO
	return Vector2i(gitter[0], gitter[1])


## Zeichnet eine Form mittig auf [param canvas].
##
## Die Zellengröße ergibt sich aus [code]canvas.size[/code] — mit festen
## Pixelwerten gäbe es auf schmalen Seitenverhältnissen Überläufe.
## [param anteil] bestimmt, wie viel der Fläche belegt wird.
## [param bezug] ist das Gitter, auf das skaliert wird; bei [code](0, 0)[/code]
## das umschließende Rechteck der Form selbst.
func _zeichne_form(canvas: Control, flach: PackedInt32Array, farbe: Color,
		anteil: float, bezug: Vector2i = Vector2i.ZERO) -> void:
	var zellen := _entpacke(flach)
	if zellen.is_empty():
		return
	var flaeche := canvas.size
	if flaeche.x <= 4.0 or flaeche.y <= 4.0:
		return

	var breite := 0
	var hoehe := 0
	for z in zellen:
		breite = maxi(breite, z.x + 1)
		hoehe = maxi(hoehe, z.y + 1)

	var skala_breite := maxi(bezug.x, breite)
	var skala_hoehe := maxi(bezug.y, hoehe)
	var kante := minf(flaeche.x / float(skala_breite), flaeche.y / float(skala_hoehe)) * anteil
	var ursprung := Vector2(
		(flaeche.x - kante * breite) * 0.5,
		(flaeche.y - kante * hoehe) * 0.5)

	var belegt := {}
	for z in zellen:
		belegt[z] = true

	for z in zellen:
		var p := ursprung + Vector2(z.x, z.y) * kante
		canvas.draw_rect(Rect2(p, Vector2(kante, kante)), farbe, true)

	# Innenkanten dünn in Hintergrundfarbe, Außenkanten dick und hell: Das
	# Gitter bleibt sichtbar und die Silhouette springt ins Auge. Beides
	# zusammen macht das Drehen im Kopf überhaupt erst nachvollziehbar.
	#
	# Zwei Durchgänge, erst alle Nähte, dann alle Ränder — sonst schneidet
	# die Naht einer später gezeichneten Zelle die Silhouette der Nachbarin an.
	#
	# Gezeichnet wird mit [method CanvasItem.draw_rect] statt mit
	# [method CanvasItem.draw_line]: Alle Kanten liegen achsenparallel, und ein
	# Rechteck deckt garantiert Pixel ab. Eine Linie tut das nicht — sie füllt
	# nur Pixel, deren Mittelpunkt sie trifft. Auf einem Antwortfeld ist eine
	# Zelle rund 30 px groß, die Naht damit ein Haarstrich, und je nachdem, wo
	# die Kante zwischen zwei Pixelmitten landet, fiel sie ersatzlos aus. Dann
	# verschmolzen zwei Zellen optisch zu einem langen Balken und die Form war
	# falsch ablesbar. Deshalb auch die Untergrenze von 2 px — dieselbe, die
	# die anderen grafischen Minispiele für ihre Striche benutzen.
	var naht := maxf(2.0, kante * 0.05)
	var rand := maxf(2.0, kante * 0.11)
	var rand_farbe := farbe.lightened(0.45)
	for aussen in [false, true]:
		var dicke := rand if aussen else naht
		var strich_farbe := rand_farbe if aussen else HINTERGRUND
		for z in zellen:
			var p := ursprung + Vector2(z.x, z.y) * kante
			for i in 4:
				# Kante i zeigt in Richtung NACHBARN[i] — oben, rechts, unten,
				# links. Das Band liegt mittig auf der Kante.
				if belegt.has(z + NACHBARN[i]) == aussen:
					continue
				var halb := dicke * 0.5
				var feld: Rect2
				match i:
					0:
						feld = Rect2(p.x, p.y - halb, kante, dicke)
					1:
						feld = Rect2(p.x + kante - halb, p.y, dicke, kante)
					2:
						feld = Rect2(p.x, p.y + kante - halb, kante, dicke)
					_:
						feld = Rect2(p.x - halb, p.y, dicke, kante)
				canvas.draw_rect(feld, strich_farbe, true)
