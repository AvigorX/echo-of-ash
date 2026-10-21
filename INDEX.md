# INDEX — Echoes of Ash

Indice del pacchetto. Non è una seconda documentazione: serve a **trovare** le informazioni.
Documenti principali: [`README.md`](README.md) (cos'è, come si avvia, cosa funziona) ·
[`CHECKPOINT.md`](CHECKPOINT.md) (stato operativo, trappole, debiti, ripresa).

| | |
|---|---|
| Stato del progetto | vertical slice giocabile, **congelato** per archiviazione (20/10/2026) |
| Motore | Godot 4.7.2.stable.official (`ed1daf0bf`) |
| Verifica minima | `bash verify.sh` → exit 0 |
| Commit di riferimento | il commit iniziale di questo repository (vedi `git log`) |

---

## 1. Documenti

| File | Cosa contiene | Quando leggerlo |
|---|---|---|
| `README.md` | descrizione, funzionalità, architettura, avvio, test, stato reale, limiti, licenza | per primo, se il progetto non lo conosci |
| `CHECKPOINT.md` | stato verificato, mappa del codice con righe, cosa manca con criteri di accettazione, buchi di verifica, trappole misurate, convenzioni, rollback | prima di modificare qualcosa |
| `INDEX.md` | questo file | per orientarsi |
| `docs/ARCHITECTURE-EN.md` | specifica tecnica originale in inglese (architettura, scelte di design, verifica dettagliata) | per il *perché* delle scelte |
| `out/shot_01…07*.png` | evidenza visiva dello slice (spawn, combattimento, dialogo, inventario, pausa, primo piano, notte) | per vedere il gioco senza avviarlo |

## 2. Mappa dei componenti

| Sistema | File | Note |
|---|---|---|
| Composizione e ciclo di gioco | `scripts/systems/game.gd` (477 righe) | mondi, loot, respawn, input, pausa; unico punto che conosce tutti gli altri |
| Ciclo giorno/notte | `scripts/systems/day_night.gd` | `CanvasModulate` |
| Griglia e query del mondo | `scripts/world/world_data.gd` | logica pura, hash del layout, guardia terraferma |
| Generazione procedurale | `scripts/world/world_generator.gd` | rumore, soglie, POI, BFS, rovine, props, entità |
| Resa del terreno | `scripts/world/ground_texture.gd` | `Image` → `ImageTexture` |
| Props / acqua / nebbia / luci | `scripts/world/prop_visual.gd`, `water_overlay.gd`, `fog_layer.gd`, `light_layer.gd` | solo disegno |
| Giocatore | `scripts/player/player.gd`, `player_visual.gd` | logica vs presentazione |
| Nemici | `scripts/enemies/enemy.gd`, `enemy_visual.gd` | FSM a 6 stati + due silhouette |
| Combattimento | `scripts/combat/combat.gd`, `effects.gd` | arco melee puro; effetti |
| Oggetti | `scripts/items/item_db.gd`, `inventory.gd`, `pickup.gd` | dati, regole, pickup |
| Interazione | `scripts/interact/interactable.gd`, `npc.gd`, `brazier.gd` | contratto + due implementazioni |
| UI | `scripts/ui/hud.gd` (454 righe) | tutta la UI, costruita in codice |

Dettaglio riga per riga e testabilità headless: `CHECKPOINT.md` §3.

## 3. Punti di ingresso

- **Eseguire il gioco**: `project.godot` → `run/main_scene = res://scenes/main.tscn`.
- **Capire il flusso**: `scripts/systems/game.gd` (`_ready`, `start_world`, `_unhandled_input`).
- **Capire la generazione**: `scripts/world/world_generator.gd` (`generate`, `make_stream`).
- **Capire il combattimento**: `scripts/combat/combat.gd` (`resolve_melee`) + `player.gd` (`try_attack`).
- **Capire la UI**: `scripts/ui/hud.gd` (costruzione nodi, `_draw`).

## 4. Test e strumenti

| File | Tipo | Cosa prova |
|---|---|---|
| `tests/test_world.gd` | suite headless, exit code | 29 controlli sul generatore (biomi, props, connettività, determinismo) |
| `tests/test_gameplay.gd` | suite headless, exit code | 77 controlli end-to-end (movimento, danno, IA, loot, NPC, HUD, rigenerazione) |
| `tests/test_visual.gd` | suite **GUI** (GPU), exit code | 8 controlli di rendering falsificabili (colore-firma, diff) |
| `tests/capture.gd` | sonda **GUI** | 7 screenshot in `out/` |
| `tests/inspect_shots.gd` | sonda | mappa ASCII / palette degli screenshot |
| `tests/perf.gd` | sonda | numeri (generazione, nodi, memoria, fps headless), nessuna asserzione |
| `verify.sh` | gate | check-only su ogni `.gd` + import + avvio + le due suite headless |

Le sonde `test_visual`, `capture`, `inspect_shots` richiedono una finestra: in headless non
producono pixel utili. `perf.gd` misura solo CPU/nodi: il profilo di rendering non è coperto.

## 5. Dove NON guardare

- `out/` è escluso dall'import Godot (`.gdignore`): non è contenuto di gioco, solo output di sonde.
- `.godot/` è cache rigenerabile, non versionata.
- Non esistono audio, salvataggi o asset: se un documento li cita come presenti, è un piano
  (`CHECKPOINT.md` §6), non uno stato.

## 6. Collegamenti

- Stato e verifiche: `README.md` §8–§9 · `CHECKPOINT.md` §4–§5, §10
- Cosa manca e in che ordine: `CHECKPOINT.md` §6
- Cosa **non** è provato: `CHECKPOINT.md` §7
- Trappole già pagate (non ripeterle): `CHECKPOINT.md` §8
- Convenzioni di codice: `CHECKPOINT.md` §9
- Backup e ripristino: `CHECKPOINT.md` §11
