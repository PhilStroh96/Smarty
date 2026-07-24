extends QuizMinigame

## Kopfrechnen: Eine Rechnung, vier Ergebnisse, eines stimmt.
##
## Referenzimplementierung für alle textbasierten Minispiele.
##
## Zwei Dinge, die jedes Minispiel beachten muss:
## [br]1. Ausschließlich [param task_rng] als Zufallsquelle.
## [br]2. Die falschen Antworten müssen [i]plausibel[/i] sein. Zufällige
##    Zahlen kann man ohne Rechnen ausschließen — das Spiel misst dann
##    Mustererkennung statt Kopfrechnen. Deshalb liegen die Ablenker nahe
##    am richtigen Ergebnis und treffen typische Rechenfehler.

const OPTION_COUNT := 4


func _init() -> void:
	id = &"rechnen_zielzahl"
	category = Category.RECHNEN
	duration_sec = 60.0
	tutorial_text = "Rechne im Kopf und tippe das richtige Ergebnis an."


func _make_task(index: int, task_rng: SeededRng) -> MinigameTask:
	# Schwierigkeit steigt über den Spielverlauf: erst zweistellige
	# Addition, später Multiplikation und gemischte Terme.
	var stage := _stage_for(index)
	var parts := _build_term(stage, task_rng)
	var prompt: String = parts["prompt"]
	var answer: int = parts["answer"]

	var options := _build_options(answer, task_rng)
	return MinigameTask.new(prompt, options, options.find(str(answer)))


## 0 = Addition, 1 = Subtraktion, 2 = kleines Einmaleins, 3 = gemischt.
func _stage_for(index: int) -> int:
	var base := index / 5
	# difficulty verschiebt den Einstieg, damit derselbe Code für einen
	# leichten Trainingsmodus und für eine harte Partie taugt.
	return clampi(base + int(difficulty * 2.0), 0, 3)


func _build_term(stage: int, r: SeededRng) -> Dictionary:
	match stage:
		0:
			var a := r.next_int(12, 49)
			var b := r.next_int(11, 39)
			return {"prompt": "%d + %d" % [a, b], "answer": a + b}
		1:
			var a := r.next_int(35, 95)
			var b := r.next_int(11, 34)
			return {"prompt": "%d − %d" % [a, b], "answer": a - b}
		2:
			var a := r.next_int(3, 9)
			var b := r.next_int(3, 9)
			return {"prompt": "%d × %d" % [a, b], "answer": a * b}
		_:
			var a := r.next_int(3, 9)
			var b := r.next_int(3, 9)
			var c := r.next_int(4, 25)
			return {"prompt": "%d × %d + %d" % [a, b, c], "answer": a * b + c}


## Baut vier Antworten: die richtige plus drei plausible Ablenker.
func _build_options(answer: int, r: SeededRng) -> Array[String]:
	var values: Array[int] = [answer]

	# Typische Rechenfehler zuerst — Zahlendreher, Vertipper um eins,
	# Zehnerfehler. Die verraten sich nicht auf den ersten Blick.
	var candidates: Array[int] = [
		answer + 10, answer - 10, answer + 1, answer - 1,
		answer + 2, answer - 2, answer + 9, answer - 9,
		answer + 20, answer - 20,
	]
	r.shuffle(candidates)

	for c in candidates:
		if values.size() >= OPTION_COUNT:
			break
		# Keine Duplikate und keine negativen Ergebnisse — beides wäre
		# sofort als falsch erkennbar und würde die Aufgabe verschenken.
		if c > 0 and not values.has(c):
			values.append(c)

	# Notnagel, falls die Kandidaten nicht reichten (sehr kleine Ergebnisse).
	var extra := 1
	while values.size() < OPTION_COUNT:
		if not values.has(answer + extra):
			values.append(answer + extra)
		extra += 1

	r.shuffle(values)

	var out: Array[String] = []
	for v in values:
		out.append(str(v))
	return out
