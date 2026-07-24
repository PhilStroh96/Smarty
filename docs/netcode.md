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
   │   └─ RelayTransport   (Gast, übers Relay)    │
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

## Der Gratis-Weg: host-autoritativ + Relay

Statt einen bezahlten Spielserver zu betreiben, läuft der `MatchServer` auf
dem Gerät des **Hosts** — genau der Code, der schon offline läuft. Die Cloud
ist nur ein dummer Weiterleiter:

```
   Gast-Handy          Cloudflare-Worker         Host-Handy
   MatchClient  ──cmd──▶   Relay (Raum)   ──cmd──▶  MatchServer
   RelayTransport ◀─evt──   (dumm)         ◀─evt──  RelayHostBridge
```

- **`RelayHostBridge`** (Host): Server-Events → alle Gäste; Gast-Commands →
  Server, mit vom Relay **authentifiziertem** Absender (kein Gast kann im
  Namen eines anderen handeln — das M3-Anti-Cheat gilt auch über Netz).
- **`RelayTransport`** (Gast): schickt Commands, empfängt Events. Für den
  `MatchClient` nicht von `LocalTransport` unterscheidbar.
- **`LoopbackHub`**: der Relay im selben Prozess, für Tests. Bildet die
  Weiterleitung exakt nach — headless getestet in `relay_fidelity_test`.
- **`WebSocketEndpoint`** + **`server/relay-worker/`**: der echte Weg über
  einen Cloudflare Durable Object. Kostenlos (Free-Tier, Hibernation).
  Deploy: [server/relay-worker/README.md](../server/relay-worker/README.md).

**Warum das kostenlos geht:** Der Worker versteht das Spiel nicht und hält
keinen Zustand über die Partie hinaus — er leitet nur weiter und schläft
zwischen Nachrichten. Kein Server, den man bezahlt oder administriert.

**Trade-off:** Der Host ist die Autorität — er *könnte* schummeln. Unter
Freunden ist das der Normalfall (so arbeiten Konsolen-Partygames auch), und
Gäste können weiterhin nicht schummeln. Für einen breiten Release wäre ein
echter, neutraler Server nötig.

## Offen für echten Online-Betrieb

1. **Cloudflare-Worker deployen** — braucht deinen (kostenlosen) Cloudflare-
   Account. Danach die Worker-URL in die Godot-Seite eintragen.
2. **Online-Lobby-UI** — Bildschirm zum Erstellen/Beitreten per Code, den
   Host-Start, die Charakterwahl. Die Logik (`Lobby`, `RelayTransport`)
   steht; es fehlt die Oberfläche und die Verdrahtung einer Online-Brett-
   szene (der Gast baut seinen `GameState` aus Presence + `MATCH_STARTED`).
3. **Host-Migration** während der Partie — aktuell endet die Runde, wenn der
   Host geht.
4. **Package-Name final** vor dem ersten Store-Upload (siehe
   [android-export.md](android-export.md)).
5. **Deep-Links** zum Teilen des Codes per WhatsApp — der wichtigste
   Verbreitungskanal für ein Party-Game.

Ein neutraler, bezahlter Server (Nakama o. ä.) bleibt der Weg für einen
breiten Release — dann als weitere `NetTransport`-Implementierung, ohne den
Rest anzufassen.
