extends QuizMinigame

## Zahlenreihen: Vier oder fünf Glieder stehen da, das nächste ist gesucht.
##
## Gemessen wird Mustererkennung, nicht Kopfrechnen. Deshalb bleiben alle
## Zahlen dreistellig oder kleiner — wer erst dividieren muss, um die Regel
## zu sehen, spielt ein anderes Spiel.
##
## Zwei Dinge bestimmen den Aufbau:
## [br]1. [b]Eindeutigkeit.[/b] Es werden so viele Glieder gezeigt, dass nur
##    eine Fortsetzung sinnvoll ist. Konstante Schritte verraten sich schon
##    nach drei Differenzen, alternierende und wachsende Differenzen brauchen
##    vier — also fünf Glieder.
## [br]2. [b]Plausible Ablenker.[/b] Jede falsche Antwort ist das Ergebnis
##    eines echten Denkfehlers: Regel einmal zu oft angewandt, Differenz
##    nicht mitwachsen lassen, den falschen Schritt des Paares genommen.
##    Zufallszahlen kann man ohne Nachdenken ausschließen, dann misst die
##    Aufgabe nichts.
## [br]3. [b]Keine geschenkten Ausschlüsse.[/b] Zwei Fehlerbilder sehen auf
##    dem Papier plausibel aus, sind es aber nicht: eine Zahl, die schon in
##    der Reihe steht (bei konstanter Schrittweite trifft "Vorzeichen
##    verwechselt" immer ein sichtbares Glied), und eine Zahl auf der
##    falschen Seite des letzten Gliedes bei streng steigender Reihe. Beides
##    streicht man ohne Rechnen — die Aufgabe hätte dann nur noch drei
##    Antworten. Deshalb liegen bei den monotonen Reihen alle Ablenker
##    zwischen dem letzten Glied und der doppelt angewandten Regel.
## [br]4. [b]Kein Positionstrick.[/b] Zu jeder Aufgabe gibt es etwa gleich
##    viele Ablenker über wie unter der Lösung. Sonst steht die Lösung nach
##    Größe sortiert immer auf demselben Platz und man rät sie, ohne die
##    Reihe gelesen zu haben.

const OPTION_COUNT := 4

## So viele Glieder stehen bei einfachen Reihen vor dem Fragezeichen.
const TERMS_SIMPLE := 4

## So viele bei alternierenden und wachsenden Reihen — mit weniger wäre die
## Regel nicht zwingend ablesbar.
const TERMS_COMPLEX := 5


func _init() -> void:
	id = &"analysieren_reihe"
	category = Category.ANALYSIEREN
	duration_sec = 60.0
	tutorial_text = "Erkenne die Regel der Zahlenreihe und tippe die nächste Zahl an."


func _make_task(index: int, task_rng: SeededRng) -> MinigameTask:
	# Schwierigkeit steigt über den Spielverlauf: erst konstante Schritte,
	# später Multiplikation, wachsende Differenzen und alternierende Regeln.
	var stage := _stage_for(index)
	var series := _build_series(stage, task_rng)
	var terms: Array = series["terms"]
	var answer: int = series["answer"]
	var traps: Array = series["traps"]

	var parts := PackedStringArray()
	for t in terms:
		parts.append(str(t))
	parts.append("?")

	var options := _build_options(answer, traps, terms, task_rng)
	return MinigameTask.new(", ".join(parts), options, options.find(str(answer)))


## 0 = Addition, 1 = Subtraktion, 2 = Multiplikation,
## 3 = wachsende Differenz, 4 = alternierend.
func _stage_for(index: int) -> int:
	# difficulty verschiebt den Einstieg, damit derselbe Code für einen
	# leichten Trainingsmodus und für eine harte Partie taugt.
	var stage := index / 4 + int(difficulty * 2.0)
	if stage <= 4:
		return maxi(stage, 0)
	# Über Stufe 4 hinaus gibt es nichts Schwereres mehr. Statt bis zum
	# Zeitablauf dieselbe Regel zu zeigen, wechseln sich die beiden
	# schwersten ab — sonst wird das letzte Drittel eintönig.
	return 3 + index % 2


## Erzeugt Glieder, Lösung und die zur Regel passenden Ablenker.
func _build_series(stage: int, r: SeededRng) -> Dictionary:
	match stage:
		0:
			# Konstante Addition. Drei gleiche Differenzen genügen.
			#
			# Schrittweite mindestens 4: Zwischen dem letzten Glied und der
			# Lösung müssen drei ganze Zahlen Platz haben, sonst gibt es keine
			# drei Ablenker unterhalb der Lösung, die nicht sofort auffallen.
			var step := r.next_int(4, 12)
			var terms := _arithmetic(r.next_int(2, 30), step, TERMS_SIMPLE)
			var last: int = terms[terms.size() - 1]
			var answer := last + step
			return {
				"terms": terms,
				"answer": answer,
				"traps": [
					# Regel einmal zu oft angewandt.
					last + 2 * step,
					# Enge Verrechner. Alle liegen zwischen dem letzten Glied
					# und der doppelt angewandten Regel: keiner ist ohne
					# Rechnen auszuschließen, und über wie unter der Lösung
					# stehen gleich viele.
					answer + 1, answer + 2,
					answer - 1, answer - 2, answer - 3,
				],
			}
		1:
			# Konstante Subtraktion. Der Startwert liegt so hoch, dass weder
			# Lösung noch Ablenker ins Negative rutschen.
			var step := r.next_int(4, 12)
			var start := r.next_int(5 * step + 4, 5 * step + 40)
			var terms := _arithmetic(start, -step, TERMS_SIMPLE)
			var last: int = terms[terms.size() - 1]
			var answer := last - step
			return {
				"terms": terms,
				"answer": answer,
				"traps": [
					# Regel einmal zu oft angewandt.
					last - 2 * step,
					# Enge Verrechner, gespiegelt zur Addition: alles liegt
					# zwischen der doppelt angewandten Regel und dem letzten
					# Glied, also im Bereich, den die Reihe noch durchläuft.
					answer - 1, answer - 2,
					answer + 1, answer + 2, answer + 3,
				],
			}
		2:
			# Multiplikation mit 2 oder 3. Der Startwert ist so gedeckelt,
			# dass die Lösung dreistellig bleibt.
			var factor := r.next_int(2, 3)
			var top := 20 if factor == 2 else 6
			var terms := _geometric(r.next_int(2, top), factor, TERMS_SIMPLE)
			var last: int = terms[terms.size() - 1]
			var prev: int = terms[terms.size() - 2]
			var answer := last * factor
			return {
				"terms": terms,
				"answer": answer,
				"traps": [
					2 * last - prev,      # letzte Differenz konstant weitergeführt
					last * (factor + 1),  # falscher Faktor
					answer + factor, answer - factor, answer + 10, answer - 10,
				],
			}
		3:
			# Wachsende Differenz (+2, +4, +6, ...). Fünf Glieder, damit vier
			# Differenzen sichtbar sind — bei dreien wäre auch eine andere
			# Wachstumsregel denkbar.
			var grow := r.next_int(1, 3)
			var first_step := r.next_int(1, 6)
			var values := _growing(r.next_int(2, 40), first_step, grow, TERMS_COMPLEX + 1)
			var terms := values.slice(0, TERMS_COMPLEX)
			var answer: int = values[TERMS_COMPLEX]
			var last: int = terms[terms.size() - 1]
			var prev_step: int = last - terms[terms.size() - 2]
			var next_step := answer - last
			return {
				"terms": terms,
				"answer": answer,
				"traps": [
					# Differenz nicht mitwachsen lassen. Identisch mit
					# answer - grow, deshalb steht das nicht noch einmal in
					# der Liste — sonst blieben bei grow == 1 nur drei
					# verschiedene Ablenker übrig und das Antwortmuster wäre
					# jedes Mal dasselbe.
					last + prev_step,
					# Immer die erste Differenz addiert, das Wachstum ganz
					# übersehen.
					last + first_step,
					# Regel einmal zu oft angewandt.
					last + 2 * next_step,
					# Differenz einmal zu viel gewachsen, dazu enge Verrechner.
					answer + grow, answer + 1, answer + 2, answer - 1, answer - 2,
				],
			}
		_:
			# Alternierend (+7, -3, +7, -3, ...). Fünf Glieder sind das
			# Minimum: Erst dann wiederholt sich das Paar sichtbar.
			var up := r.next_int(5, 12)
			var down := r.next_int(2, up - 2)
			var values := _alternating(r.next_int(3, 30), up, down, TERMS_COMPLEX + 1)
			var terms := values.slice(0, TERMS_COMPLEX)
			var answer: int = values[TERMS_COMPLEX]
			var last: int = terms[terms.size() - 1]
			return {
				"terms": terms,
				"answer": answer,
				"traps": [
					last - down,        # falscher Schritt des Paares
					last + up - down,   # beide Schritte auf einmal
					last + up + down,   # beide Schritte addiert statt abwechselnd
					last + 2 * up,      # den Abwärtsschritt übersprungen
					# Der naheliegende Ablenker last + down fehlt bewusst: er
					# trifft immer genau das vierte Glied der Reihe, steht
					# also schon sichtbar da und ist gratis auszuschließen.
					answer + 1, answer + 2, answer - 1, answer - 2,
				],
			}


## Reihe mit konstanter Schrittweite. Negativer [param step] zählt abwärts.
func _arithmetic(start: int, step: int, count: int) -> Array[int]:
	var out: Array[int] = []
	var value := start
	for _i in count:
		out.append(value)
		value += step
	return out


## Reihe mit konstantem Faktor.
func _geometric(start: int, factor: int, count: int) -> Array[int]:
	var out: Array[int] = []
	var value := start
	for _i in count:
		out.append(value)
		value *= factor
	return out


## Reihe, deren Differenz je Schritt um [param grow] zunimmt.
func _growing(start: int, first_step: int, grow: int, count: int) -> Array[int]:
	var out: Array[int] = []
	var value := start
	var step := first_step
	for _i in count:
		out.append(value)
		value += step
		step += grow
	return out


## Reihe, die abwechselnd [param up] addiert und [param down] abzieht.
func _alternating(start: int, up: int, down: int, count: int) -> Array[int]:
	var out: Array[int] = []
	var value := start
	for i in count:
		out.append(value)
		value += up if i % 2 == 0 else -down
	return out


## Baut vier Antworten: die richtige plus drei Ablenker aus [param traps].
##
## [param terms] sind die sichtbaren Glieder. Sie werden gebraucht, um
## Ablenker auszusortieren, die schon in der Aufgabe stehen.
func _build_options(answer: int, traps: Array, terms: Array, r: SeededRng) -> Array[String]:
	var values: Array[int] = [answer]

	var candidates: Array[int] = []
	for t in traps:
		candidates.append(int(t))
	r.shuffle(candidates)

	for c in candidates:
		if values.size() >= OPTION_COUNT:
			break
		if _usable(c, values, terms):
			values.append(c)

	# Notnagel, falls die Ablenker nicht reichten. Abwechselnd nach oben und
	# unten, damit ein Nachrücken die Lösung nicht systematisch an denselben
	# Platz der sortierten Liste schiebt.
	var extra := 1
	while values.size() < OPTION_COUNT and extra < 100:
		for c in [answer + extra, answer - extra]:
			if values.size() < OPTION_COUNT and _usable(c, values, terms):
				values.append(c)
		extra += 1

	r.shuffle(values)

	var out: Array[String] = []
	for v in values:
		out.append(str(v))
	return out


## Taugt [param value] als Ablenker?
##
## Drei Ausschlussgründe, alle aus demselben Grund: Wer sie erkennt, muss die
## Reihe nicht gelesen haben.
## [br]- Null oder negativ: kommt in keiner dieser Reihen vor.
## [br]- Schon als Antwort vergeben.
## [br]- Steht sichtbar in der Aufgabe. Eine Zahl, die man gerade abgelesen
##   hat, ist als nächstes Glied offensichtlich falsch.
func _usable(value: int, values: Array[int], terms: Array) -> bool:
	return value > 0 and not values.has(value) and not terms.has(value)
