class_name MinigameResult
extends RefCounted

## Das Ergebnis eines Minispiels für einen Spieler.
##
## Das ist die komplette Nutzlast, die pro Minispiel über das Netz geht
## (PLAN.md §2.1) — bewusst winzig gehalten.

## Punktzahl, nach der die Platzierung bestimmt wird. Höher ist besser.
var score: int = 0

## Anzahl korrekter Antworten.
var correct: int = 0

## Anzahl falscher Antworten.
var wrong: int = 0

## Durchschnittliche Antwortzeit in Millisekunden.
var avg_time_ms: int = 0

## Rohdaten der Einzelantworten — für die Server-Validierung.
## Format pro Eintrag: { "task": int, "answer": int, "time_ms": int }
var submissions: Array[Dictionary] = []


func _init(p_score: int = 0, p_correct: int = 0, p_wrong: int = 0) -> void:
	score = p_score
	correct = p_correct
	wrong = p_wrong


## Trägt eine Einzelantwort nach und aktualisiert die Kennzahlen.
func add_submission(task_index: int, answer: int, time_ms: int, is_correct: bool) -> void:
	submissions.append({
		"task": task_index,
		"answer": answer,
		"time_ms": time_ms,
	})
	if is_correct:
		correct += 1
	else:
		wrong += 1
	_recalc_avg_time()


func _recalc_avg_time() -> void:
	if submissions.is_empty():
		avg_time_ms = 0
		return
	var total: int = 0
	for s in submissions:
		total += s["time_ms"] as int
	avg_time_ms = total / submissions.size()


func to_dict() -> Dictionary:
	return {
		"score": score,
		"correct": correct,
		"wrong": wrong,
		"avg_time_ms": avg_time_ms,
		"submissions": submissions,
	}


static func from_dict(d: Dictionary) -> MinigameResult:
	var r := MinigameResult.new()
	r.score = d.get("score", 0)
	r.correct = d.get("correct", 0)
	r.wrong = d.get("wrong", 0)
	r.avg_time_ms = d.get("avg_time_ms", 0)
	var subs: Array = d.get("submissions", [])
	for s in subs:
		r.submissions.append(s as Dictionary)
	return r
