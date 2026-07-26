# Art Bible — Mobile Smarty

Richtung: **Prisma (Flat-Vektor)**. Stand: gewählt am 2026-07-25.

Dieses Dokument ist verbindlich. Jedes Asset — ob prozedural erzeugt oder
später von Hand/KI — muss sich daran halten. Konsistenz entsteht *vor* dem
Zeichnen, durch feste Constraints (PLAN.md §3.1), nicht durch Nachbessern.

Vorteil dieser Richtung: Flat-Vektor lässt sich prozedural (`tools/gen_prisma_art.py`)
**nahezu final** erzeugen — pixelgenau, versionierbar, keine KI-Konsistenz-
probleme. Der Look ist bewusst geometrisch und flächig; Tiefe kommt aus
Kantenlicht und Seitenschattierung, nicht aus Texturen oder Verläufen.

## Palette (exakt, nicht abweichen)

| Rolle | Hex |
|---|---|
| Hintergrund Mitte | `#242A54` |
| Hintergrund außen | `#101228` |
| Feld Normal | `#3E8EF7` |
| Feld Bonus | `#F6A821` |
| Feld Falle | `#EE4B44` |
| Feld Stern | `#9B6BFF` |
| Feld Start | `#2FD98A` |
| Kontur / Outline | `#141733` |
| UI-Akzent (Gold) | `#FFD264` |
| Spieler 1–4 | `#FF4D5E` · `#2E9BFF` · `#FFC93C` · `#1FB36B` |

Der Goldton führt die bestehende App-Identität (Menü, HUD) konsequent weiter.

## Licht & Tiefe

- **Lichtquelle fest oben-links.** Keine Ausnahmen.
- **Seitenwände** der Tiles: linke Wand = Oberfarbe × 0.62, rechte Wand
  = Oberfarbe × 0.78. So wirkt das Feld erhaben, ohne Verlauf.
- **Kantenlicht**: die beiden oberen Kanten der Diamant-Oberseite bekommen
  eine helle Linie (Oberfarbe × 1.22). Das ist der Prisma-Signature-Look.
- **Oberseite bleibt flach** (eine Farbe). Flat-Vektor lebt von der Fläche,
  nicht vom Farbverlauf.

## Tile-Anatomie

- Diamant-Oberseite **128 × 64** px (2:1-Isometrie).
- Seitenwand **20** px hoch. Texturgröße also **128 × 84**.
- Outline **2** px, Farbe `#141733`, umläuft die gesamte Silhouette.
- Sechs Rollen nebeneinander im Atlas: Normal, Bonus, Falle, Stern, Start, Deko.

## Feld-Symbole (barrierefrei — Pflicht)

Bedeutung ist **dreifach kodiert**: Farbe **und** Helligkeit **und Form**.
Niemals nur über Rot/Grün unterscheiden (Farbenblindheit). Der geplante
Farbenblind-Modus tauscht nur den Symbol-Layer, die Geometrie bleibt.

| Rolle | Symbol (Form) |
|---|---|
| Normal | kleiner Punkt |
| Bonus | dickes Plus `+` |
| Falle | dicker Balken `−` |
| Stern | fünfzackiger Stern |
| Start | Wimpel/Play-Dreieck |

Symbolfarbe = Oberfarbe × 0.40 (dunkle, satte Prägung), mit 1 px hellem
Unterrand für Lesbarkeit auf kleinen Displays.

## Figuren

- Grundmaß **48 × 72** px pro Figur (passt zu `board/pawn/pawn.gd`).
- Flat-Vektor: runder Körper (Kegelstumpf mit weichen Ecken) + Kugelkopf,
  2 px Outline `#141733`, Kantenlicht oben-links.
- **Vier Spielerfarben** (siehe Palette).
- **Unterscheidung auch ohne Farbe** (Barrierefreiheit): jede Figur trägt eine
  eigene **Kopfform** — P1 Krönchen, P2 Cap mit Schirm, P3 Antenne/Bommel,
  P4 Blatt. So sind die Spieler auch bei Rot-Grün-Schwäche eindeutig.
- Einfaches freundliches Gesicht (zwei Augen, Glanzpunkt oben-links).
- Weicher Kontaktschatten unter der Figur (eigene, vorgerenderte Ellipse).

## Hintergrund & Bühne

- Kein einfarbiger Grund. Radialer Verlauf: Mitte `#242A54` → außen `#101228`
  (leichtes „Bühnenlicht" auf das zentrierte Brett).
- Weicher dunkler Schatten unter dem gesamten Brett zur Erdung.
- Ruhig halten: der Hintergrund darf die Felder nicht überstrahlen.

## UI

- Dunkle Paneele, Gold-Akzent `#FFD264` für Primäraktionen.
- Große Touch-Ziele (≥ 96 px bei Zeitdruck), runde Ecken, klare Kontraste.
- Keine feinen Texturen — funktioniert für Oma wie Enkel auf kleinen Displays.

## Was diese Richtung NICHT ist

- Keine Farbverläufe auf Tile-Oberseiten (das wäre ein anderer Stil).
- Keine weichen/aquarelligen Kanten (das wäre Richtung B).
- Kein Neon-Glow (das wäre Richtung D).
- Später umskinnbar auf eine reichere Richtung — die Geometrie und
  Silhouetten sind hier fixiert, die Spiellogik bleibt unberührt.
