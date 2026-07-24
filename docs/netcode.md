# Netcode-Architektur

Stand: M3-Fundament. Der Online-Betrieb läuft noch nicht — die Architektur
ist gebaut und getestet, der echte Server fehlt (siehe [Offene
Entscheidungen](#offene-entscheidungen)).

## Grundidee

Der springende Punkt aus [PLAN.md](../PLAN.md) §2.1: **Minispiele werden
nicht synchronisiert.** Der Server verteilt einen Seed, alle Geräte
erzeugen daraus lokal dieselben Aufgaben, übertragen werden nur die
Antworten. Das verwandelt den klassischen Netcode-Albtraum in ein paar
Dutzend Bytes pro Minispiel — und ist latenztolerant, weil eine Denkaufgabe
200 ms Ping nicht spürt.

Damit das trägt, muss die gesamte Spiellogik **deterministisch** sein:
gleicher Seed → bit-genau gleiches Ergebnis, auf jedem Gerät. Das ist die
Eigenschaft, die der Determinismus-Test und der Netcode-Partietest absichern.

## Die Schichten

```
   ┌─────────────────────────────────────────────┐
   │  board_scene · HUD · MinigameRunner          │   Darstellung
   └───────────────────┬─────────────────────────┘
                       │  hohe Signale (turn_started, …)
   ┌───────────────────┴─────────────────────────┐
   │  MatchClient                                 │   Client: spiegelt,
   │  - Ereignis-Warteschlange, Wiedergabe        │   animiert, rechnet nichts
   └───────────────────┬─────────────────────────┘
                       │  Commands ↓   Events ↑
   ┌───────────────────┴─────────────────────────┐
   │  NetTransport (abstrakt)                     │   die Naht
   │   ├─ LocalTransport   (im selben Prozess)    │
   │   └─ NakamaTransport  (noch zu bauen)        │
   └───────────────────┬─────────────────────────┘
                       │
   ┌───────────────────┴─────────────────────────┐
   │  MatchServer                                 │   die einzige Wahrheit:
   │  - autoritativ, deterministisch, headless    │   würfelt, wertet, prüft
   └─────────────────────────────────────────────┘
```

- **Command** (Client → Server): eine Absicht. „Ich möchte würfeln." Ob und
  was fällt, entscheidet der Server.
- **Event** (Server → Clients): eine Tatsache. „Spieler 2 hat eine 4
  gewürfelt und steht jetzt auf Feld 9 mit 12 Münzen." Der Client übernimmt
  das nur.

Alle Nachrichten sind reine `Dictionary`-Werte aus Zahlen, Strings und
Arrays — kein Objekt, keine Referenz. Grund: Sie gehen später als JSON über
Nakama.

## Warum das jetzt schon so gebaut ist

Der `LocalTransport` lässt Server und Client im selben Prozess laufen. Er
trägt zwei Rollen:

1. **Offline-/Hotseat-Modus** — der Regelfall auf einem Gerät, funktioniert
   ohne Internet. Der Fallback, wenn niemand online ist oder der Server
   ausfällt.
2. **Testbett** — eine ganze Partie läuft deterministisch in Millisekunden
   durch, ohne Netzwerk.

Nakama einzuhängen heißt dann: eine zweite `NetTransport`-Implementierung
schreiben, die Commands über die Leitung schickt und Events empfängt. Client,
Server-Logik, Minispiele, HUD — nichts davon ändert sich.

## Anti-Cheat

Der Server vertraut **keiner** vom Client gemeldeten Punktzahl. Der Client
schickt nur seine rohen Antworten (`{task, answer, time_ms}`). Der Server:

1. prüft die Zeiten auf Plausibilität (`validate_submission`): nichts unter
   150 ms menschlicher Reaktionszeit, nichts nach Ablauf des Timers, monoton
   steigend;
2. baut aus dem Seed dieselben Aufgaben und rechnet die Punkte selbst nach
   (`authoritative_score`).

Ein Client kann so nur seine Antworten behaupten, niemals sein Ergebnis.

## Disconnect

Bei mobilen Spielern ist Verbindungsverlust der Normalfall (PLAN.md §4.2).
Der Server behandelt einen abwesenden Spieler wie einen KI-Spieler: Läuft
die Zug-Deadline ab, übernimmt die KI (`taken_over_by_ai`), würfelt für ihn
und die Partie läuft für alle anderen weiter. Dasselbe bei Minispiel-Abgaben.

## Testabdeckung

| Test | Was er absichert |
|---|---|
| `determinism_test` | `SeededRng` liefert plattformgleiche Folgen |
| `board_match_test` | Server-Partie: Event-Determinismus, Invarianten, autoritative Wertung, Validierung |
| `client_flow_test` | Der animierte Client spielt eine Partie bis zum Ende ab |
| `lobby_test` | Beitreten, Kapazität, Bereit-Status, Host-Migration, Codes |

## Offene Entscheidungen

Bevor der echte Online-Betrieb gebaut werden kann, braucht es von dir:

1. **Nakama-Hosting.** Empfehlung aus dem Plan: erst Heroic Cloud (managed,
   ~50–200 €/Monat), später self-hosted. Das bestimmt, wie der
   `NakamaTransport` sich verbindet.
2. **Package-Name final.** Nach dem ersten Store-Upload unveränderlich —
   hängt am endgültigen Spielnamen (siehe [android-export.md](android-export.md)).
3. **Server-seitige Wertung.** Aktuell rechnet der Server die Minispiel-
   Punkte in GDScript nach. Auf einem Godot-Dedicated-Server läuft das
   unverändert. Bei Nakama-mit-Go müsste die Wertungslogik nach Go portiert
   werden — oder ein Godot-Headless-Prozess dient als Match-Handler. Diese
   Weiche gehört vor den Nakama-Bau geklärt.

## Was der Nakama-Schritt konkret umfasst

- `NakamaTransport extends NetTransport` — Verbindung, Auth (Device-ID),
  Command senden, Events empfangen.
- Server-seitiger Match-Handler, der `MatchServer` antreibt (Godot-Dedicated)
  oder dessen Logik spiegelt (Go).
- Lobby über Nakama-Matchmaking statt der lokalen `Lobby`-Klasse — die
  Zustandslogik bleibt, der Transport wechselt.
- Reconnect-Fenster, Presence, Host-Migration während der Partie.
- Deep-Links zum Teilen des Lobby-Codes (WhatsApp — der wichtigste
  Verbreitungskanal für ein Party-Game).
