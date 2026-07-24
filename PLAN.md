# Mobile Smarty — Projektplan

> Party-Brettspiel für Mobile mit Logik-Minispielen.
> Referenzen: Wii Party / Mario Party (Brett + Minispiel-Loop), Big Brain Academy (Minispiel-Inhalte).
>
> **Stack-Entscheidung:** Godot 4.7.1 · Online-Multiplayer mit Lobby-Code · Ziel Store-Release
> Stand: Juli 2026

---

## 0. Die ehrliche Vorbemerkung

Du hast die drei anspruchsvollsten Optionen gewählt. Das ist völlig legitim, aber du solltest wissen, worauf du dich einlässt:

| Faktor | Realität |
|---|---|
| Online-Multiplayer | Verdreifacht mindestens den Engineering-Aufwand ggü. lokal. Server-Betrieb = laufende Kosten + Wartung, auch nachts, auch an Weihnachten. |
| Store-Release als Ziel | Compliance, Store-Assets, Ratings, Support, Updates. Rechne 25–30 % der Gesamtzeit auf Dinge, die nichts mit "Spiel bauen" zu tun haben. |
| Content-Menge | Party-Games leben von Masse. 20+ Minispiele sind das Minimum für Wiederspielwert. Jedes braucht Design, Code, Art, Audio, Balancing, Lokalisierung. |

**Realistische Zeitschätzung bis Store-Release:**

- Solo, Vollzeit, mit KI-Unterstützung: **14–20 Monate**
- Kleines Team (2–3 Personen: Code / Art / Design+Audio): **8–12 Monate**
- Solo, nebenberuflich (~12 h/Woche): **2,5–3,5 Jahre** — in dieser Konstellation dringend Scope kürzen

**Meine Empfehlung, ohne dein Ziel zu ändern:** Wir behalten "Store-Release" als Zielbild und bauen die Architektur von Tag 1 dafür. Aber wir setzen bei **M2 und M4 harte Gates** ein (siehe §6). Wenn der Kern-Loop dort keinen Spaß macht, ist das die billigste Stelle zum Umsteuern. Das ist kein Zurückrudern — das ist, wie Studios es machen.

---

## 1. Spielkonzept

### 1.1 Kern-Loop

```
Lobby (Code eintippen)
   ↓
Karte wählen  →  4 Spieler, 10–15 Runden
   ↓
┌─────────────── RUNDE ───────────────┐
│  Jeder Spieler: Würfel → Bewegung   │
│  Feld-Effekt (Bonus/Falle/Ereignis) │
│         ↓                            │
│  MINISPIEL (alle gleichzeitig)      │
│  Platzierung → Münzen               │
│         ↓                            │
│  Alle 5 Runden: Stern-Event         │
└──────────────────────────────────────┘
   ↓
Endwertung + Boni  →  Ergebnisbildschirm  →  Rematch?
```

**Zieldauer einer Partie: 12–18 Minuten.** Das ist die wichtigste Zahl im ganzen Dokument. Mario Party dauert 60–90 min — das funktioniert auf dem Sofa vor der Konsole, aber nicht mobil. Mobile Sessions brechen ab. Wenn eine Partie länger als 20 Minuten dauert, verlierst du Spieler mitten im Spiel, und bei Online-Multiplayer ruiniert jeder Abbrecher die Partie für drei andere.

### 1.2 Das Alleinstellungsmerkmal

Die Kombination ist der Punkt: Mario-Party-Minispiele sind **Geschicklichkeit** (schnell tippen, Timing). Big Brain Academy ist **Denken**. Ein Party-Game, das auf *Köpfchen* statt Reflexe setzt, hat einen echten Winkel:

- Funktioniert generationsübergreifend — Oma kann gegen den Enkel gewinnen
- Touch-Steuerung ist für Logik-Aufgaben *besser* geeignet als für Action (kein Präzisionsproblem, keine fehlenden Buttons)
- Weniger Frust durch Hardware-Unterschiede (kein Vorteil durch besseres Handy/Latenz)
- Fairness bei Netzwerk-Lag: Denkaufgaben sind latenztolerant, Reaktionsspiele nicht

**Positionierung in einem Satz:** *"Das Partyspiel, bei dem Köpfchen gewinnt — 15 Minuten, 4 Freunde, ein Lobby-Code."*

### 1.3 Minispiel-Kategorien (Big-Brain-Systematik)

Fünf Kategorien, damit sich das Spiel abwechslungsreich anfühlt und keine Spielergruppe strukturell benachteiligt ist. Ziel: **Pro Kategorie 4–6 Spiele zum Launch (= 20–30 gesamt).**

| Kategorie | Fähigkeit | Beispiel-Minispiele |
|---|---|---|
| **Erkennen** | Schnelle visuelle Unterscheidung | Welche Gruppe hat mehr? · Finde das Duplikat · Farbe-vs-Wort (Stroop) |
| **Merken** | Kurzzeitgedächtnis | Karten-Memory unter Zeitdruck · Reihenfolge nachklopfen · Was hat sich verändert? |
| **Analysieren** | Logik, Muster, Schlussfolgern | Zahlenreihe fortsetzen · Waage ausbalancieren · Odd-one-out |
| **Rechnen** | Kopfrechnen | Ziel-Zahl bauen · Schneller Vergleich · Wechselgeld zählen |
| **Vorstellen** | Räumliches Denken | Würfel-Netz falten · Formen rotieren · Puzzleteil einpassen |

**Wichtige Design-Regel:** Jedes Minispiel muss in **unter 8 Sekunden erklärt** sein (ein Satz + eine Grafik) und **45–75 Sekunden** dauern. Bei 4 Spielern online gibt es keine Chance auf lange Tutorials.

**Zweite Design-Regel — Aufholmechanik:** Reines Können-vs-Können frustriert schwächere Spieler und tötet Party-Games. Braucht:
- Bonus-Felder und Zufalls-Events auf der Karte, die Rückstände ausgleichen
- Endboni ("Meiste Minispiele gewonnen", "Weiteste Strecke") mit spürbarem Gewicht
- Optionales, unsichtbares Difficulty-Scaling pro Spieler in Solo-Modi

### 1.4 Modi zum Launch

1. **Party (Online)** — 2–4 Spieler, Lobby-Code, der Hauptmodus
2. **Party (Lokal/Hotseat)** — ein Gerät, wandert herum. *Kritisch als Fallback:* funktioniert offline, im Zug, ohne Freunde online. Kostet fast nichts extra, wenn die Architektur stimmt.
3. **Minispiel-Marathon** — Solo, alle Spiele hintereinander, Highscore
4. **Tägliches Training** — Big-Brain-Modus: 5 Aufgaben, Gehirn-Score, Statistik über Zeit. **Das ist deine Retention-Mechanik** — der Grund, warum jemand die App öffnet, wenn gerade keine Freunde da sind.

---

## 2. Technische Architektur

### 2.1 Der wichtigste Netcode-Trick

Das hier spart dir Monate, also lies es zweimal:

**Rundenbasierte Brettphase → Server-autoritativ, simpel.** Würfeln, Bewegung, Feld-Effekte. Sekundentakt, kein Lag-Problem, kein Prediction nötig. Server würfelt, Server entscheidet, Clients zeigen die Animation. Fertig.

**Minispiele → NICHT synchronisieren. Nur Ergebnisse übertragen.**

Statt Spielerpositionen 30×/Sekunde zu syncen (der klassische Netcode-Albtraum), läuft jedes Minispiel **lokal auf jedem Gerät** mit einem vom Server vorgegebenen **Seed**. Alle sehen dieselben Aufgaben in derselben Reihenfolge. Übertragen wird nur:

```
Client → Server:  { antwort_id, zeit_ms, aufgabe_index }
Server → Clients: { rangliste, punkte }   (nach Ablauf des Timers)
```

Der Server validiert gegen den Seed und plausibilisiert die Zeiten (nichts unter ~150 ms menschlicher Reaktionszeit, keine Antwort nach Timer-Ende). Das ist:

- **Bandbreite:** ein paar Dutzend Bytes pro Minispiel statt Kilobytes pro Sekunde
- **Latenztolerant:** 200 ms Ping sind bei einer Denkaufgabe irrelevant
- **Cheat-resistent genug** für ein Party-Game
- **Testbar** ohne laufenden Server

Damit das funktioniert, muss die Minispiel-Logik **deterministisch** sein: eigener seeded RNG, niemals `randi()` global, keine Physik mit Float-Drift, keine Abhängigkeit von Framerate oder Bildschirmgröße für die Spiellogik.

Ein Live-Fortschrittsbalken der Gegner ("Anna ist bei Aufgabe 4") lässt sich als sparsames Broadcast (2–4 Updates/Sekunde) nachrüsten — das reicht völlig für das Gefühl von Wettkampf.

### 2.2 Backend-Empfehlung

**Nakama** (Open Source, offizieller GDScript-Client) — nicht selbst bauen.

Du bekommst fertig: Auth (Device-ID, Apple/Google Sign-In), Lobbies & Matchmaking, Custom Match Handler in Go/TS für deine Spiellogik, Leaderboards, Storage, Presence/Reconnect.

Deployment-Pfad: **Erst Heroic Cloud** (managed, ~50–200 €/Monat je nach Spielerzahl). Wenn die Nutzerzahlen es rechtfertigen, später auf self-hosted (Hetzner o. ä., ~20–40 €/Monat + deine DevOps-Zeit) migrieren. Falsch herum anzufangen — erst self-hosten, um Geld zu sparen — kostet dich Wochen an Ops-Arbeit, die du in Minispiele stecken solltest.

**Bau keinen eigenen Server**, außer du hast einen sehr konkreten Grund. Reconnect-Handling, Matchmaking, Session-Migration, Skalierung — das sind gelöste Probleme.

### 2.3 Projektstruktur

```
mobile-smarty/
├─ project.godot
├─ addons/
│  └─ nakama/                  # Nakama GDScript SDK
├─ core/
│  ├─ autoload/                # GameState, Net, Audio, Settings, Analytics
│  ├─ net/                     # Nakama-Wrapper, Match-Handler-Bindings
│  ├─ rng/                     # SeededRNG — die einzige erlaubte Zufallsquelle
│  └─ save/                    # Lokaler Speicherstand, Cloud-Sync
├─ board/
│  ├─ maps/                    # Eine Szene pro Karte
│  ├─ tiles/                   # Feldtypen + Effekte
│  └─ pawn/                    # Spielfiguren, Bewegung, Kamera
├─ minigames/
│  ├─ _base/                   # MinigameBase — das Interface, s.u.
│  ├─ erkennen/
│  ├─ merken/
│  ├─ analysieren/
│  ├─ rechnen/
│  └─ vorstellen/
├─ ui/                         # Lobby, HUD, Ergebnisse, Menüs, Shop
├─ assets/
│  ├─ art/{tiles,characters,ui,fx}
│  ├─ audio/{music,sfx,vo}
│  └─ source/                  # Aseprite/Blender-Quelldateien, NICHT im Export
├─ i18n/                       # Übersetzungs-CSV
├─ tools/                      # Asset-Import-Skripte, Tile-Validierung
└─ tests/                      # GUT-Tests, v. a. Determinismus
```

### 2.4 Das Minispiel-Interface — die wichtigste Abstraktion

Jedes Minispiel erbt von `MinigameBase` und implementiert einen fixen Vertrag. Wenn das früh stimmt, kostet Minispiel Nr. 20 einen Bruchteil von Nr. 1. Wenn es nicht stimmt, wird jedes Minispiel ein Sonderfall und das Projekt erstickt.

```gdscript
class_name MinigameBase
extends Node

# --- Metadaten (Editor-sichtbar) ---
@export var id: StringName
@export var category: Category          # ERKENNEN | MERKEN | ANALYSIEREN | RECHNEN | VORSTELLEN
@export var duration_sec: float = 60.0
@export var tutorial_text: String       # EIN Satz, max. ~60 Zeichen
@export var tutorial_anim: PackedScene

# --- Lifecycle ---
func setup(seed: int, difficulty: float) -> void:
    # Deterministischer Aufbau. NUR SeededRNG verwenden.
    pass

func start() -> void: pass
func tick(delta: float) -> void: pass

# --- Ergebnis ---
func get_result() -> MinigameResult:
    # { score:int, correct:int, wrong:int, avg_time_ms:int }
    pass

# --- Server-Validierung (läuft headless im Match-Handler) ---
static func validate(seed: int, submissions: Array) -> bool:
    pass
```

**Regel:** Kein Minispiel darf auf `GameState`, Netzwerk oder Bildschirmgröße zugreifen. Es bekommt einen Seed, gibt ein Ergebnis zurück, sonst nichts. Damit ist jedes Minispiel einzeln startbar, testbar und headless validierbar.

### 2.5 Isometrische 2.5D-Darstellung

**Ansatz: 2D-Sprites in isometrischer Projektion** (nicht echtes 3D). Deutlich billiger in Performance und Produktion, und der "spaßige Stil" lebt sowieso von handgemachtem Charme, nicht von echter Geometrie.

- Godots `TileMapLayer` im **isometrischen Modus**, 2:1-Projektion (Standard, gut lesbar auf kleinen Displays)
- **Tile-Basisgröße: 128×64 px** (Diamant). Groß genug für moderne Displays, klein genug für vertretbare Atlas-Größen.
- **`YSortEnabled`** auf Tilemap und Figuren — regelt die Verdeckung automatisch
- Höhe/Stufen über Tile-Offsets und separate Layer, nicht über echte Z-Achse
- Charaktere: **4 Blickrichtungen genügen** bei Iso (NO, NW, SO, SW) — spiegelbar auf 2 Sets. Das halbiert die Art-Arbeit gegenüber 8 Richtungen und fällt kaum auf.
- Parallax-Hintergrund + leichte Kamera-Neigung/Wackeln für den "2.5D"-Eindruck
- Optional als Politur: Partikel und weiche Schatten als eigener Layer

**Mobile-Performance-Regeln (früh setzen, spart Wochen):**
- Renderer: **Mobile** (nicht Forward+), `project.godot` von Anfang an so konfigurieren
- Textur-Kompression **ASTC** für beide Plattformen
- Sprite-Atlasse ≤ 2048×2048, Draw Calls im Blick behalten
- Zielbudget: **60 FPS auf einem Mittelklasse-Gerät von ~2022** (nicht auf deinem Handy testen — das lügt)

### 2.6 Auflösung & Eingabe

- Basisauflösung **1080×1920** (Portrait) oder **1920×1080** (Landscape) — **Entscheidung nötig, siehe §8**
- Stretch-Mode `canvas_items`, Aspect `expand`
- **Safe Areas**: Notches, Dynamic Island, Gestenleisten. Nie interaktive Elemente in die äußeren 60 px legen.
- Touch-Ziele **mindestens 48×48 dp**, bei Zeitdruck-Minispielen lieber 64 dp
- **Nur Tap und Swipe.** Kein Multitouch, kein Drag-Präzisionsspiel, kein Tilt — das schließt Spieler aus und geht auf schwachen Geräten schief.

---

## 3. Asset-Pipeline

### 3.1 Zuerst das Art Bible, dann generieren

Der häufigste Fehler bei KI-generierten Assets: drauflosgenerieren und am Ende 200 Bilder haben, die nicht zusammenpassen. Konsistenz entsteht **vor** der Generierung, durch Constraints.

Das Art Bible legt verbindlich fest — als Dokument, das in jeden Prompt eingeht:

- **Farbpalette:** 24–32 Farben, festgeschrieben als Hex-Werte. Jedes Asset wird darauf quantisiert.
- **Lichtrichtung:** immer gleich (z. B. oben-links), Schattenfarbe fix
- **Outline:** Stärke und Farbe festgelegt (oder konsequent keine)
- **Proportionen:** Charaktere z. B. 2,5 Köpfe hoch, definierte Silhouetten-Regeln
- **Tile-Anatomie:** 128×64 Diamant, Oberseite sichtbar, Seitenflächen X px hoch
- **Detailgrad:** definierte Obergrenze — auf 6" Display verschwindet Detail sowieso

### 3.2 Workflow pro Asset

```
Art Bible + Referenzbild
   ↓
KI-Generierung (Batch, gleicher Style-Anker)
   ↓
Aussortieren (erwarte 20–30 % Trefferquote)
   ↓
Manuelle Nachbearbeitung (Aseprite/Photoshop):
   Palette quantisieren · Ränder säubern · Auf Tile-Raster einpassen
   ↓
tools/validate_asset.py  (Größe, Palette, Transparenz, Namensschema)
   ↓
Import nach Godot
```

**Tools:** Sprixen oder Scenario (beide mit Style-Lock/Custom-Training) für Konsistenz-kritische Sets · PixelLab für Charakter-Richtungen · Aseprite für Nachbearbeitung und Animation. **Erwarte 5–10× Beschleunigung, nicht 100×.** Die Nachbearbeitung ist echte Arbeit und lässt sich nicht wegautomatisieren.

### 3.3 ⚠️ Rechtliche Prüfung vor dem Store-Release

Das ist kein Detail, sondern ein Blocker:

- **Kommerzielle Lizenz prüfen** — nicht jedes KI-Tool erlaubt kommerzielle Nutzung im Free-Tier. Screenshots der Lizenzbedingungen zum Zeitpunkt der Generierung archivieren.
- **Urheberrecht:** In DE/EU sind rein KI-generierte Werke **nicht urheberrechtlich geschützt** — du kannst Dritte nicht daran hindern, deine Assets zu verwenden. Für Logo und Maskottchen deshalb **substanzielle menschliche Bearbeitung** (dokumentiert) oder Auftragsarbeit eines Menschen.
- **Marke:** Spielname und Logo auf Kollisionen prüfen und Wortmarke anmelden (DPMA ~300 €, EUIPO ~850 €). Vor dem Launch, nicht danach.
- Keine erkennbaren Nintendo-Anleihen. Der Stil darf „nintendoesk" sein, die Figuren nicht.

### 3.4 Audio

Oft unterschätzt, prägt aber den "spaßigen Stil" mindestens so stark wie die Grafik:

- 1 Titeltrack, 2–3 Board-Loops, 1 Minispiel-Track pro Kategorie (loopbar, 60–90 s), 1 Ergebnis-Fanfare
- SFX: UI-Klicks, Würfel, Bewegung, richtig/falsch, Countdown, Jubel/Aua
- Charakter-Vocals: Kauderwelsch-Silben statt echter Sprache — spart die komplette Lokalisierung und passt zum Genre
- Quellen: eigenes Setup, Auftragsarbeit (~1.500–4.000 € für ein Launch-Paket), oder lizenzierte Bibliotheken

---

## 4. Online-Multiplayer im Detail

### 4.1 Lobby-Flow

```
Host: "Spiel erstellen" → Server erzeugt 4-stelligen Code (z. B. K7QM)
                        → Wartebildschirm, Spieler tröpfeln ein
Gäste: Code eintippen  → Beitreten → Charakter wählen → Bereit
Host: "Start"          → Karte + Regeln festgelegt → Match beginnt
```

**Codes:** 4 Zeichen aus einem verwechslungsarmen Alphabet (kein 0/O, 1/I/L). Ablauf nach 10 Minuten Inaktivität. Zusätzlich Deep-Link zum Teilen per WhatsApp — das ist der wichtigste Verbreitungskanal für ein Party-Game und sollte nicht erst nachträglich kommen.

### 4.2 Disconnect-Handling — nicht optional

Bei mobilen Spielern ist Verbindungsverlust der **Normalfall**, nicht die Ausnahme: Tunnel, Anruf, App im Hintergrund, WLAN-zu-Mobilfunk-Wechsel. Wenn das schlecht gelöst ist, ist dein Spiel kaputt, egal wie gut es sonst ist.

- **Reconnect-Fenster von 60 Sekunden**, Spielstand bleibt am Server erhalten
- Bei Timeout: **KI übernimmt die Figur** und spielt zu Ende — die Partie läuft für alle anderen weiter
- App im Hintergrund: Godots `NOTIFICATION_APPLICATION_PAUSED` abfangen, Socket am Leben halten
- **Runden-Timer mit Auto-Zug**, damit niemand die Partie durch Nichtstun blockiert
- Verlässt der Host, wandert die Host-Rolle automatisch weiter

### 4.3 Test-Setup

Multiplayer-Bugs, die du nicht reproduzieren kannst, fressen ganze Wochen. Deshalb von Anfang an:
- Godots Feature „Run multiple instances" für 4 lokale Clients
- Netzwerk-Bedingungen simulieren (`clumsy` unter Windows): 200 ms Latenz, 2 % Paketverlust als Standard-Testprofil
- Ein Test, der eine komplette Partie headless durchspielt — läuft in CI bei jedem Commit
- Determinismus-Tests: gleicher Seed → identisches Ergebnis, auf allen Plattformen

---

## 5. Compliance & Store — früh einplanen

Diese Punkte klingen langweilig, blockieren aber den Release, wenn sie zu spät kommen.

### 5.1 Die wichtigste Produktentscheidung: kein Text-Chat

**Empfehlung: nur vordefinierte Emotes und Sticker, kein freier Text.**

Sobald du freien Chat anbietest, greifen 2026 verschärfte Regeln: Google Plays Child-Safety-Standards und Age-Restricted-Content-Policies stellen zusätzliche Anforderungen an Chat-Funktionen, die Families-Policy verbietet anonymen Chat in Apps, die sich an Kinder richten. Du bräuchtest Moderation, Meldefunktion, Altersverifikation — ein eigenes Teilprojekt mit laufenden Kosten.

Emotes lösen 90 % des sozialen Bedürfnisses ("Ha!", "Gut gemacht", "Ups") und kosten dich nichts an Compliance. Für ein Party-Game unter Freunden, die meist ohnehin nebeneinander sitzen oder telefonieren, ist das die richtige Wahl.

### 5.2 Alterseinstufung & Datenschutz

- Zielrating **USK 0 / PEGI 3 / ESRB Everyone** — maximale Reichweite, aber löst Familien-Policies aus
- **Falls Kinder unter 13 zur Zielgruppe gehören:** Google Play Families Policy + COPPA. Die COPPA-Novelle (volle Compliance seit April 2026) zählt inzwischen Geolocation, biometrische Daten und persistente Kennungen wie Geräte-IDs als personenbezogene Daten, mit separater Opt-in-Elternzustimmung für Werbe-Targeting.
- **DSGVO** (du sitzt in DE): Datenschutzerklärung, Rechtsgrundlagen, Auskunfts- und Löschrecht, AVV mit dem Backend-Hoster
- **Datensparsamkeit ist hier die Abkürzung:** Wenn du keine Klarnamen, keine Mailadressen, keine Standortdaten und keine Werbe-IDs erhebst, schrumpft der Compliance-Aufwand dramatisch. Anonyme Device-ID-Accounts + selbstgewählter Anzeigename reichen für dieses Spiel vollständig.
- Anzeigenamen filtern (Schimpfwortliste) — sonst hast du die Chat-Problematik durch die Hintertür wieder drin

### 5.3 Konten & Kosten

| Posten | Kosten |
|---|---|
| Apple Developer Program | 99 $/Jahr |
| Google Play Developer | 25 $ einmalig |
| Backend (Heroic Cloud, Start) | ~50–200 €/Monat |
| Domain + Website (Impressum, Datenschutz, Support) | ~50 €/Jahr |
| Markenanmeldung (optional, empfohlen) | ~300 € (DE) / ~850 € (EU) |
| KI-Asset-Tools | ~20–60 €/Monat |
| Audio (Auftragsarbeit, falls extern) | ~1.500–4.000 € einmalig |

⚠️ **Für iOS brauchst du zwingend einen Mac** zum Bauen und Signieren. Falls nicht vorhanden: Mac mini (~700 €) oder ein CI-Dienst mit macOS-Runnern.

### 5.4 Monetarisierung

Für ein Party-Game mit Online-Fokus:

- **Empfehlung: Premium mit kostenloser Demo.** Erste Karte + 8 Minispiele gratis, Vollversion 4,99–7,99 €. Passt zum Genre, keine Werbe-Compliance, keine Kaufdruck-Mechanik gegenüber Kindern, und die Free-Version wird zum Marketingkanal.
- **Wichtig für Party-Games:** Wenn *ein* Spieler die Vollversion hat, sollten alle in seiner Lobby mitspielen können ("Host teilt den Inhalt"). Das ist der stärkste Kaufanreiz überhaupt und macht aus jedem Käufer einen Verkäufer.
- Kosmetik-DLC (Charakter-Skins, Bretter) als spätere Erweiterung
- **Keine Werbung.** Unterbricht den Party-Flow, löst zusätzliche Kinder-Compliance aus, und die Erträge sind bei dieser Sessionlänge minimal.

---

## 6. Meilensteine

### M0 · Fundament (1–2 Wochen)
Godot 4.7.1, Android SDK + OpenJDK 17, Git mit Git-LFS für Assets. Projekt mit Mobile-Renderer, Zielauflösung und Ordnerstruktur. `SeededRNG` + Autoloads. Ein graues Rechteck, das auf deinem echten Handy läuft.
→ **Ergebnis:** Build-Pipeline steht. Ab hier landet jede Änderung binnen Minuten auf dem Gerät.

### M1 · Board-Prototyp (3–4 Wochen)
Isometrische TileMap mit Platzhalter-Tiles. Eine Testkarte, Figurenbewegung entlang Pfad, Kamera-Follow. Würfel, Zugreihenfolge, 3 Feldtypen. Rundenlogik lokal.
→ **Ergebnis:** Vier Platzhalter-Figuren laufen im Kreis. Sieht hässlich aus, fühlt sich aber schon nach Brettspiel an.

### M2 · Minispiel-Framework + erste 6 (4–6 Wochen) 🚦 **GATE**
`MinigameBase` final. Ein Minispiel pro Kategorie plus eins extra. Ergebnisbildschirm, Münzvergabe, Einbindung in die Rundenlogik. Komplette Partie lokal durchspielbar.
→ **🚦 Gate:** Fünf Menschen, die nicht du sind, spielen eine volle Partie im Hotseat. **Fragen: Wollen sie eine zweite Runde? Lachen sie? Welches Minispiel überspringen sie am liebsten?**
→ Wenn hier kein Funke überspringt, wird kein Netcode und keine hübsche Grafik das retten. Diese Erkenntnis ist an dieser Stelle 20.000 € wert.

### M3 · Netcode (5–7 Wochen)
Nakama-Setup, Auth, Lobby mit Code, Match-Handler mit autoritativer Brettlogik, Seed-Verteilung, Ergebnis-Validierung, Reconnect + KI-Übernahme. Deep-Links.
→ **Ergebnis:** Vier Leute in vier Städten spielen eine Partie zu Ende — inklusive einer Person, die zwischendurch in die U-Bahn steigt.

### M4 · Art & Audio Produktion (8–10 Wochen, teils parallel) 🚦 **GATE**
Art Bible. Finales Charakter-Set (4–6 Figuren × 4 Richtungen × Animationen). Tilesets für 3 Karten. UI-Kit. FX. Kompletter Audio-Satz. Alle Platzhalter ersetzt.
→ **🚦 Gate:** Ein Fremder sieht einen 20-Sekunden-Clip. Versteht er ohne Erklärung, was das Spiel ist — und will er es spielen?

### M5 · Content-Ausbau (6–8 Wochen)
Aufstocken auf 20–25 Minispiele und 3–4 Karten. Balancing. Progression, Freischaltungen, Statistiken. Tägliches Training. Lokalisierung DE/EN (+ ES/FR/PT-BR, wenn Budget da ist).

### M6 · Politur & Launch (5–7 Wochen)
Performance auf Zielgeräten. Onboarding und Tutorials. Barrierefreiheit (Farbenblind-Modus — bei Logik-Minispielen essenziell; Schriftgrößen; reduzierte Bewegung). Store-Assets, Trailer, Screenshots. Datenschutz + Impressum + Support-Adresse. IAP. Closed Beta (TestFlight / Play Internal Testing) mit ≥ 30 echten Spielern. Absturz-Monitoring. Soft-Launch in einem kleinen Markt vor dem globalen Release.

**Summe: ~32–44 Wochen reine Entwicklungszeit** — ohne Krankheit, Urlaub, Umwege und die Wochen, in denen ein Bug drei Tage frisst. Deshalb oben die Spanne von 14–20 Monaten solo.

---

## 7. Risiken

| Risiko | Wahrscheinlichkeit | Gegenmaßnahme |
|---|---|---|
| Minispiele machen einzeln Spaß, die Partie aber nicht | Hoch | M2-Gate mit echten Testspielern, bevor Geld in Art fließt |
| Online-Partien brechen ab, Frust | Hoch | KI-Übernahme + Reconnect von Anfang an, nicht als Nachrüstung |
| Content-Menge unterschätzt | Sehr hoch | Framework-Investition in M2; Minispiel Nr. 15 muss in 2 Tagen machbar sein |
| KI-Assets wirken inkonsistent | Mittel | Art Bible vor der ersten Generierung, automatisierte Validierung |
| Rechteproblem bei KI-Assets | Mittel | Lizenzen archivieren, Logo/Maskottchen menschlich bearbeiten |
| Serverkosten ohne Umsatz | Mittel | Premium statt F2P; Lokalmodus funktioniert auch bei Serverausfall |
| Kein iOS-Build möglich (kein Mac) | — | Früh klären, ggf. Android-First-Launch |
| Niemand findet das Spiel | Sehr hoch | Ab M4 öffentlich devloggen (TikTok/Reddit/Discord); Marketing beginnt nicht beim Launch |

**Das unterschätzteste Risiko ist das letzte.** Ein gutes, unentdecktes Spiel ist der Normalfall im Store. Plane Sichtbarkeit als Arbeitspaket ein, nicht als Hoffnung.

---

## 8. Offene Entscheidungen

Die brauche ich von dir, bevor M0 startet:

1. **Portrait oder Landscape?** — Portrait ist einhändig und mobiltypisch. Landscape gibt der isometrischen Karte deutlich mehr Luft. *Meine Empfehlung: Landscape für die Brettansicht, Portrait für Lobby/Menüs — Godot kann das umschalten, kostet aber doppeltes UI-Layout. Wenn du dich für eins entscheiden musst: **Landscape**, wegen der Karte.*
2. **Spielerzahl:** 2–4 fix, oder bis 6/8?  *Empfehlung: 4. Mehr Spieler = längere Wartezeiten pro Zug = tödlich für Mobile-Sessions.*
3. **Solo/Team oder Auftragsarbeit?** — Bestimmt Zeitplan und Budget maßgeblich.
4. **Mac für iOS vorhanden?** — Falls nein: Android-First planen.
5. **Budget-Rahmen** für Tools, Backend, Audio, Marketing?
6. **Arbeitstitel** — bleibt es "Mobile Smarty"? (Namensrecherche gehört früh gemacht, nicht kurz vor Launch.)

---

## 9. Nächster Schritt

Wenn du grünes Licht gibst, starte ich mit **M0**:

- Godot 4.7.1 installieren und Projekt anlegen (Mobile-Renderer, Zielauflösung, Ordnerstruktur)
- Git-Repo mit LFS und passender `.gitignore`
- `SeededRNG` und die Autoload-Grundstruktur
- Ein erstes isometrisches Test-Tileset als Platzhalter
- Android-Export-Kette bis zum Build auf deinem Gerät

Danach direkt in M1, damit du innerhalb weniger Wochen etwas Bewegliches auf dem Handy hast.

---

### Quellen

- [Godot Mobile Update, April 2026](https://godotengine.org/article/godot-mobile-update-apr-2026/)
- [Godot Docs — Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Nakama — Open Source Game Backend](https://heroiclabs.com/nakama/)
- [Nakama Godot Client SDK](https://github.com/heroiclabs/nakama-godot)
- [Godot 4 Multiplayer: Best Practices & Benchmarks (2026)](https://ziva.sh/blogs/godot-multiplayer)
- [Google Play — Policy Announcement, 15. April 2026](https://support.google.com/googleplay/android-developer/answer/16926792?hl=en)
- [Google Play Families Policies (Preview)](https://support.google.com/googleplay/android-developer/answer/17122218)
- [Google Play Age Verification 2026](https://qawerk.com/blog/google-play-age-verification-usa-state-laws/)
- [Consistent AI Game Assets Workflow](https://www.seeles.ai/resources/blogs/consistent-ai-game-assets-workflow)
- [PixelLab — AI Game Asset Generator](https://www.pixellab.ai/)
