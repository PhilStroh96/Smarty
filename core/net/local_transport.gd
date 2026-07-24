extends NetTransport
class_name LocalTransport

## Transport ohne Netz: Server und Client im selben Prozess.
##
## Trägt zwei Rollen:
## [br]• [b]Lokaler Spielmodus[/b] (Hotseat/offline): der Regelfall auf einem
##   Gerät. Funktioniert ohne Internet und ohne Server — der Fallback, wenn
##   niemand online ist oder der echte Server ausfällt (PLAN.md §1.4).
## [br]• [b]Testbett[/b]: Weil hier kein Netz dazwischenliegt, lässt sich eine
##   ganze Partie deterministisch und in Millisekunden durchspielen.
##
## Die Zeit ist steuerbar: Im echten Spiel liefert [method _now] die
## Systemuhr, im Test setzt man [member now_override] und kann so gezielt
## Timeouts (KI-Übernahme) auslösen.

var server: MatchServer

## Im Test auf einen festen Wert setzen, um die Zeit zu kontrollieren.
## -1 = echte Systemuhr verwenden.
var now_override: int = -1


func _init(p_server: MatchServer) -> void:
	server = p_server
	server.event.connect(_relay)


func send_command(cmd: Dictionary) -> void:
	server.command(cmd, _now())


func poll() -> void:
	# In einer Schleife takten, bis der Server nichts mehr von allein tun
	# kann. So laufen mehrere KI-Züge in einem Durchgang durch; an einem
	# menschlichen Zug bleibt der Server stehen (Deadline in der Zukunft)
	# und die Schleife endet.
	var guard := 0
	while server.poll(_now()):
		guard += 1
		if guard > 10000:
			push_error("LocalTransport.poll: Schleife bricht nicht ab")
			break


## Startet die Partie über den Transport.
func start() -> void:
	server.start(_now())
	poll()


func _relay(evt: Dictionary) -> void:
	event_received.emit(evt)


func _now() -> int:
	return now_override if now_override >= 0 else Time.get_ticks_msec()
