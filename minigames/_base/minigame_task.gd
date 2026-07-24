class_name MinigameTask
extends RefCounted

## Eine einzelne Aufgabe innerhalb eines Minispiels.
##
## Bewusst so schlank: Eine Aufgabe ist eine Frage, ein paar Antworten und
## der Index der richtigen. Alles Grafische läuft über [member draw_data]
## und die Zeichenmethoden des jeweiligen Minispiels — so bleibt der
## Datentyp serialisierbar und der Server kann Aufgaben nachrechnen, ohne
## irgendetwas zu rendern.

## Fragetext. Darf leer sein, wenn die Aufgabe rein grafisch ist.
var prompt: String = ""

## Antwortmöglichkeiten als Text. Bei grafischen Antworten leer lassen und
## [member option_count] setzen.
var options: Array[String] = []

## Index der richtigen Antwort in [member options].
var correct: int = 0

## Freie Nutzdaten für grafische Darstellung — Formen, Farben, Positionen.
## Muss aus dem Seed reproduzierbar sein, damit der Server prüfen kann.
var draw_data: Dictionary = {}

## Anzahl der Antwortfelder, wenn die Antworten nicht aus [member options]
## kommen, sondern gezeichnet werden.
var option_count: int = 0

## Dauer einer Einprägephase in Sekunden. 0 = keine.
##
## Ist der Wert größer als null, zeigt die Ansicht zuerst [member study_prompt]
## bzw. die Zeichnung, blendet sie nach Ablauf aus und gibt erst dann die
## Antworten frei. Damit lassen sich Merkaufgaben im selben Rahmen bauen wie
## alle anderen — ohne einen zweiten Spieltyp und ohne eigene Ansicht.
var study_seconds: float = 0.0

## Was während der Einprägephase zu sehen ist. Bei grafischen Aufgaben
## leer lassen und in der Zeichenmethode auf die Phase reagieren.
var study_prompt: String = ""


func _init(p_prompt: String = "", p_options: Array[String] = [], p_correct: int = 0) -> void:
	prompt = p_prompt
	options = p_options
	correct = p_correct
	option_count = p_options.size()


## Wie viele Antwortfelder diese Aufgabe hat.
func answer_count() -> int:
	return maxi(options.size(), option_count)


func is_correct(chosen: int) -> bool:
	return chosen == correct
