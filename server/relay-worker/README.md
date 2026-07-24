# Relay-Worker (Cloudflare)

Der dumme Nachrichten-Weiterleiter für host-autoritatives Online-Spiel.
Kostenlos im Cloudflare-Gratis-Tier — kein Spielserver, keine Spiellogik,
nur Räume und Weiterleitung.

> **Warum host-autoritativ:** Ein Spieler (der Host) lässt den `MatchServer`
> auf seinem Gerät laufen — genau den Code, der schon offline läuft. Dieser
> Worker leitet nur Nachrichten weiter. Details und die Architektur:
> [../../docs/netcode.md](../../docs/netcode.md).

## Was du brauchst

- Einen kostenlosen [Cloudflare-Account](https://dash.cloudflare.com/sign-up).
- Node.js (hast du) und damit `wrangler`, das Cloudflare-CLI.

## Deploy in drei Schritten

```bash
cd server/relay-worker
npm install
npx wrangler login
```

`wrangler login` öffnet den Browser und verbindet dein Cloudflare-Konto.
Danach:

```bash
npx wrangler deploy
```

Am Ende gibt `wrangler` eine URL aus, etwa:

```
https://mobile-smarty-relay.<dein-name>.workers.dev
```

**Diese URL brauchst du im Spiel.** Sie kommt in die Godot-Seite (dort, wo
der `WebSocketEndpoint` erstellt wird) als `base_url`. Der Client verbindet
sich dann zu `wss://…workers.dev/room/<LOBBY-CODE>`.

## Lokal testen

```bash
npx wrangler dev
```

Startet den Worker lokal (meist auf `http://localhost:8787`). Zum Testen mit
dem Spiel `base_url` vorübergehend auf `ws://localhost:8787` setzen.

## Was das kostet

Nichts, im Rahmen des Gratis-Tiers: 100.000 Requests/Tag, und Durable Objects
mit SQLite-Speicher sind im Free-Tier enthalten. Der Worker „schläft"
zwischen Nachrichten (Hibernation) und kostet dann gar nichts. Für Runden
unter Freunden ist das um Größenordnungen mehr als genug. ([Cloudflare
Preise](https://developers.cloudflare.com/durable-objects/platform/pricing/))

## Das Protokoll

Der Worker spricht dasselbe Umschlag-Protokoll wie
`core/net/relay/relay_protocol.gd`. Die Weiterleitungslogik ist ein exaktes
Gegenstück zu `core/net/relay/loopback_hub.gd` — und die ist headless
getestet (`tests/relay_fidelity_test.gd`). Wenn du an einem der beiden etwas
änderst, muss das andere nachziehen.

| Nachricht | Richtung | Wirkung |
|---|---|---|
| `hello` {room,id,name} | Client → Relay | Raum beitreten; Ältester wird Host |
| `welcome` / `presence` | Relay → Client | Aktueller Raumstand |
| `cmd` {cmd} | Gast → Relay | Wird an den Host geschickt, mit `from` = echter Absender |
| `evt` {evt} | Host → Relay | Broadcast an alle Gäste |
| `bye` | Client → Relay | Raum verlassen |

## Grenzen (bewusst offen)

- **Host-Migration mitten in der Partie** ist noch nicht gelöst. Verlässt der
  Host, endet die Partie für die Gäste. Für Tests unter Freunden verkraftbar;
  eine echte Lösung (Server-Zustand an einen Gast übergeben) kommt später.
- **Keine Persistenz der Partie.** Fällt der Raum aus, ist die Runde weg. Das
  ist für ein 15-Minuten-Partyspiel akzeptabel.
