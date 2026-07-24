class_name NetTransport
extends RefCounted

## Die Grenze zwischen Client und Server.
##
## Der Client kennt nur dieses Interface: Er schickt Commands hinein und
## bekommt Events heraus. Ob dahinter ein Server im selben Prozess läuft
## ([LocalTransport]) oder eine Nakama-Verbindung über das Netz, ist ihm
## gleichgültig. Genau darin liegt der Wert der Abstraktion (PLAN.md §2.1):
## Der komplette Client — Animation, HUD, Minispiel-Ablauf — entsteht und
## wird getestet, lange bevor ein echter Server existiert. Nakama einzuhängen
## heißt später, eine zweite Implementierung dieser Klasse zu schreiben,
## nicht das Spiel umzubauen.

## Ein Event ist vom Server eingetroffen.
signal event_received(evt: Dictionary)

## Schickt einen Command an den Server.
func send_command(_cmd: Dictionary) -> void:
	push_error("NetTransport.send_command nicht implementiert")


## Treibt den Transport voran. Bei [LocalTransport] taktet das den Server;
## netzbasierte Transporte, die selbst Nachrichten empfangen, brauchen es
## nicht. Wird vom Client regelmäßig aufgerufen.
func poll() -> void:
	pass


## Trennt die Verbindung und gibt Ressourcen frei.
func close() -> void:
	pass
