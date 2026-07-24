// Mobile Smarty — Relay-Worker (Cloudflare)
//
// Ein dummer Weiterleiter fuer host-autoritatives Online-Spiel (docs/netcode.md).
// Ein Raum = eine Durable-Object-Instanz, benannt nach dem Lobby-Code.
// Der Worker versteht das Spiel NICHT. Er kennt nur diese Umschlag-Typen und
// muss sich exakt wie core/net/relay/loopback_hub.gd verhalten (das ist die
// getestete Referenz).
//
// Anti-Cheat: Beim Weiterreichen eines Commands an den Host stempelt der Relay
// die AUTHENTIFIZIERTE Absender-ID aus der Verbindung (dem Hello), niemals aus
// dem Nachrichteninhalt. So kann kein Gast im Namen eines anderen handeln.

// --- Umschlag-Typen (identisch zu relay_protocol.gd) ---
const HELLO = "hello";
const CMD = "cmd";
const EVT = "evt";
const BYE = "bye";
const WELCOME = "welcome";
const PRESENCE = "presence";
const ERROR = "err";

export class Room {
  constructor(state, env) {
    this.state = state;
  }

  async fetch(request) {
    const upgrade = request.headers.get("Upgrade");
    if (upgrade !== "websocket") {
      return new Response("erwartet WebSocket", { status: 426 });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    // Hibernation-API: der Worker darf zwischen Nachrichten schlafen und
    // kostet dann nichts. Der Socket-Zustand haengt an der Verbindung.
    this.state.acceptWebSocket(server);
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, raw) {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch (_e) {
      return;
    }
    switch (msg.k) {
      case HELLO:
        await this.onHello(ws, msg);
        break;
      case CMD:
        this.routeCmd(ws, msg);
        break;
      case EVT:
        this.routeEvt(ws, msg);
        break;
      case BYE:
        ws.close(1000, "bye");
        break;
    }
  }

  async webSocketClose(ws) {
    // Der Host-Wechsel ergibt sich automatisch, weil der Host aus der
    // kleinsten Beitritts-Sequenz abgeleitet wird (siehe hostId()).
    this.broadcastPresence();
  }

  async webSocketError(ws) {
    this.broadcastPresence();
  }

  // --- Beitritt ---
  async onHello(ws, msg) {
    // Fortlaufende Beitritts-Sequenz aus dem dauerhaften Speicher. Der
    // Aelteste im Raum ist der Host; das ueberlebt Hibernation, weil die
    // Sequenz am Socket haengt.
    let seq = (await this.state.storage.get("seq")) || 0;
    seq += 1;
    await this.state.storage.put("seq", seq);

    ws.serializeAttachment({ id: String(msg.id), name: String(msg.name), seq });

    this.send(ws, {
      k: WELCOME,
      id: msg.id,
      host: this.hostId(),
      members: this.members(),
    });
    this.broadcastPresence();
  }

  // --- Routing ---
  routeCmd(ws, msg) {
    const me = ws.deserializeAttachment();
    if (!me) return;
    const host = this.hostSocket();
    if (host) {
      // "from" = authentifizierte Absender-ID aus der Verbindung.
      this.send(host, { k: CMD, from: me.id, cmd: msg.cmd });
    }
  }

  routeEvt(ws, msg) {
    const me = ws.deserializeAttachment();
    if (!me || me.id !== this.hostId()) return; // nur der Host darf broadcasten
    for (const sock of this.sockets()) {
      const other = sock.deserializeAttachment();
      if (other && other.id !== me.id) {
        this.send(sock, { k: EVT, evt: msg.evt });
      }
    }
  }

  // --- Praesenz ---
  broadcastPresence() {
    const p = { k: PRESENCE, host: this.hostId(), members: this.members() };
    for (const sock of this.sockets()) this.send(sock, p);
  }

  // --- Hilfen ---
  sockets() {
    return this.state.getWebSockets().filter(
      (s) => s.readyState === WebSocket.READY_STATE_OPEN
    );
  }

  attachments() {
    return this.sockets()
      .map((s) => s.deserializeAttachment())
      .filter(Boolean);
  }

  // Der Host ist das Mitglied mit der kleinsten Beitritts-Sequenz.
  hostId() {
    const a = this.attachments();
    if (a.length === 0) return "";
    return a.reduce((min, x) => (x.seq < min.seq ? x : min)).id;
  }

  hostSocket() {
    const hid = this.hostId();
    for (const sock of this.sockets()) {
      const at = sock.deserializeAttachment();
      if (at && at.id === hid) return sock;
    }
    return null;
  }

  members() {
    return this.attachments().map((a) => ({ id: a.id, name: a.name }));
  }

  send(ws, obj) {
    try {
      ws.send(JSON.stringify(obj));
    } catch (_e) {
      // Socket bereits zu — ignorieren.
    }
  }
}

// --- Worker-Einstieg: leitet /room/<CODE> an die passende DO-Instanz ---
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter(Boolean);
    if (parts[0] !== "room" || !parts[1]) {
      return new Response("Mobile Smarty Relay. Nutze /room/<CODE>.", {
        status: 200,
      });
    }
    const code = parts[1].toUpperCase();
    const id = env.ROOMS.idFromName(code);
    const stub = env.ROOMS.get(id);
    return stub.fetch(request);
  },
};
