# Echoes of Ash

Vertical slice di un action RPG procedurale in 2D, scritto in **GDScript** per **Godot 4.7.2**.
Nessun asset importato: terreno, props, personaggi, effetti, UI e atmosfera sono disegnati dal
codice. Nessuna rete, nessun servizio esterno.

Questo repository è il **pacchetto di archivio** del progetto: contiene tutto ciò che serve per
compilarlo, eseguirlo, verificarlo e riprenderlo in mano. I report di sessione, i log e gli
artefatti temporanei sono stati rimossi; i dati unici sono stati trasferiti in
[`CHECKPOINT.md`](CHECKPOINT.md). La specifica tecnica originale (in inglese) è in
[`docs/ARCHITECTURE-EN.md`](docs/ARCHITECTURE-EN.md).

---

## 1. Visione e obiettivi

Un RPG d'azione "piccolo ma completo": un'isola generata da un seed, esplorazione libera con
movimento a 8 direzioni, combattimento melee a tempo reale, due tipi di nemici, loot, crescita del
personaggio, un NPC con dialogo e un braciere come punto di cura/respawn. Il vincolo di progetto è
**zero asset esterni**: tutto ciò che si vede è `_draw()` procedurale o `Image`/`ImageTexture`
generata a runtime.

L'obiettivo dichiarato era dimostrare il *vertical slice* (un giro di gioco completo e coerente),
non la quantità di contenuti. Il progetto è **congelato** in questo stato: vedi §9 e §12.

---

## 2. Gameplay e funzionalità presenti

Tutto quanto segue è **implementato e verificato** da un test con exit code o da uno stato
osservato (dettaglio nella tabella di §9 e in `CHECKPOINT.md` §4).

- **Mondo procedurale deterministico**: isola con rumore di elevazione + umidità e soglie a
  percentile (≈22 % acqua, ≈78 % terra), 6 biomi di suolo, 4 punti d'interesse collegati da
  sentieri BFS, 2 complessi di rovine con mura solide e varchi, ~800 props con spaziatura minima.
  Spawn sicuro garantito (area 11×11 libera).
- **Determinismo su seed**: stream RNG separati per terreno, props, entità e loot
  (`WorldGenerator.make_stream(seed, id)`); stesso seed → stesso `layout_hash`.
- **Giocatore**: `CharacterBody2D`, movimento a 8 direzioni con accelerazione/attrito, collisioni
  con i props solidi, acqua non calpestabile (sliding lungo la riva), camera con smoothing e
  limiti di mondo.
- **Combattimento**: fendente ad arco di 105°, portata 26 px, knockback, particelle, screen shake.
- **Due nemici distinti** (crawler e warden) con FSM `idle / patrol / chase / attack / hurt /
  death`, rilevamento a raggio con linea di vista, movimento obstacle-aware (7 raggi + sidestep),
  stallo e ripresa, respawn su ancora a 28 s.
- **Progressione**: XP, livelli, HP e danno crescenti, morte e rinascita, progressione mantenuta
  quando si rigenera il mondo (il nodo player viene riusato).
- **Oggetti**: 5 oggetti, inventario a 12 slot con 3 slot di equipaggiamento, drop controllati,
  raccolta con `E`, uso con `1`–`4`.
- **Interazione**: contratto `Interactable`, NPC "Wanderer" con dialogo a 4 battute e ricompensa
  una tantum, braciere che cura 35 HP con cooldown 12 s e fa da respawn.
- **UI completa in codice** (`CanvasLayer`): barre HP/XP, livello, notifiche, prompt contestuale,
  inventario, pausa (Resume / New world), schermata di morte, guida ai comandi.
- **Atmosfera**: acqua animata, nebbia radiale, glow additivo (torcia + bracieri), ciclo
  giorno/notte con `CanvasModulate`, vignetta.

**Assente per scelta o per stato di avanzamento**: audio (0 %), salvataggio su disco,
streaming a chunk, nemici a distanza, opzioni/accessibilità, export e CI. Vedi §10.

---

## 3. Architettura e tecnologie

Separazione netta in tre strati, con la logica eseguibile senza rendering:

| Strato | File | Regola |
|---|---|---|
| **Dati + logica** (nessun nodo) | `world/world_data.gd`, `world/world_generator.gd`, `items/item_db.gd`, `items/inventory.gd`, `combat/combat.gd`, `interact/interactable.gd` | funzioni pure o quasi pure, testabili headless |
| **Presentazione** | `*_visual.gd`, `effects.gd`, `ground_texture.gd`, `water_overlay.gd`, `fog_layer.gd`, `light_layer.gd`, `ui/hud.gd` | legge lo stato, non lo decide |
| **Composizione** | `systems/game.gd` | composition root: mondi, loot, respawn, input, pausa |

- Comunicazione **per segnali verso l'alto** (`Player.health_changed/damaged/died/…`,
  `Enemy.died/struck/health_changed`, `Inventory.changed`, `HUD.resume_requested/new_world_requested`).
  Nessun `get_node("../../..")`, nessun autoload.
- Tutta la casualità passa da un `RandomNumberGenerator` con seed esplicito; niente `randi()` /
  `randf()` globali.
- Scena unica: `scenes/main.tscn` (un `Node2D` con `scripts/systems/game.gd`). Tutto il resto è
  costruito a runtime.
- Il melee è un **arco interrogato**, non un'`Area2D`: scelta deliberata, perché `Area2D` rileva
  l'overlap solo dal terzo frame fisico dopo un teletrasporto (trappola misurata, `CHECKPOINT.md` §8).

---

## 4. Versioni e dipendenze

| | |
|---|---|
| Motore | **Godot 4.7.2.stable.official** (`ed1daf0bf`) — nessun addon, nessun plugin |
| `config/features` dichiarata | `PackedStringArray("4.7")` |
| Linguaggio | GDScript tipizzato, 22 script di gioco (3.504 righe) + 6 script di test (1.276 righe) |
| Asset esterni | **nessuno** (né immagini, né font, né audio) |
| Rete | nessuna chiamata, nessuna telemetria |
| Impronta del codice | `sha256 1369dae8d93ee51a330aeebf55ac817ee576d0eaf8ccec32006283d98f0545fe` (calcolata sui soli `*.gd`, `*.tscn`, `project.godot`, escluso `.godot/`) |

Ricetta dell'impronta (dalla radice del pacchetto):

```bash
find . -path ./.godot -prune -o \( -name '*.gd' -o -name '*.tscn' -o -name 'project.godot' \) -print \
  | sort | xargs sha256sum | sha256sum
```

---

## 5. Struttura delle directory

```
ECHO-OF-ASH/
├── project.godot            configurazione: scena principale, InputMap, 480×270 ×3
├── scenes/main.tscn         unica scena: radice Node2D + game.gd
├── scripts/
│   ├── systems/             game.gd (composition root), day_night.gd
│   ├── world/               world_data, world_generator, ground_texture, prop/water/fog/light
│   ├── player/              player.gd (logica), player_visual.gd (disegno)
│   ├── enemies/             enemy.gd (FSM), enemy_visual.gd
│   ├── combat/              combat.gd (arco melee puro), effects.gd
│   ├── items/               item_db, inventory, pickup
│   ├── interact/            interactable (contratto), npc, brazier
│   └── ui/                  hud.gd (tutta la UI)
├── tests/                   test_world, test_gameplay, test_visual, capture, inspect_shots, perf
├── out/                     output delle sonde visive (screenshot storici + `.gdignore`)
├── docs/
│   └── ARCHITECTURE-EN.md   specifica tecnica originale (inglese, testo integrale)
├── README.md                questo file
├── CHECKPOINT.md            continuità operativa: stato, trappole, debiti, ripresa
└── INDEX.md                 indice: dove sta cosa
```

`out/` contiene `.gdignore`: Godot non importa i PNG prodotti dalle sonde. Gli screenshot
`shot_01…07` sono l'evidenza visiva dello slice; i log storici sono stati rimossi (erano ridondanti
rispetto a `CHECKPOINT.md` §10).

---

## 6. Installazione e avvio

Prerequisito: Godot **4.7.2** (stessa minor). Nessun altro requisito.

```bash
# 1. path dell'eseguibile (adatta al tuo sistema)
export GODOT=/percorso/Godot_v4.7.2-stable_win64_console.exe   # in Windows: la variante _console
export GODOT_GUI=/percorso/Godot_v4.7.2-stable_win64.exe       # finestra reale (audio/video)

# 2. primo import (genera .godot/, necessario prima di --check-only e delle suite)
"$GODOT" --headless --path . --import

# 3. gioca (finestra 1440×810, rendering interno 480×270 scalato ×3)
"$GODOT_GUI" --path .

# 4. mondo con un seed specifico
"$GODOT_GUI" --path . -- --seed 424242
```

Il progetto si apre anche dall'editor Godot (`Import` → `project.godot`).
Il primo avvio genera il mondo (≈250 ms) e la texture del suolo (≈250 ms).

**Nota sui path**: su Windows, Godot vuole path nativi (`C:/...`), non `/c/...`. Se usi una shell
MSYS/git-bash, converti con `cygpath -m "$PWD"`.

### Comandi in gioco

| Input | Azione |
|---|---|
| `W A S D` | movimento a 8 direzioni |
| mouse | mira del fendente |
| tasto sinistro | attacco (arco 105°, portata 26 px) |
| `E` | interagisci / raccogli / avanza nel dialogo / rialzati da morto |
| `I` | inventario |
| `1` `2` `3` `4` | usa o equipaggia l'oggetto della riga |
| `ESC` | menu di pausa (Resume / New world) |
| `R` | rigenera il mondo con il seed successivo |

Il seed corrente è mostrato nell'HUD (`seed <n> · <phase>`). Seed di default: `20261019`.

---

## 7. Test ed esecuzione delle verifiche

```bash
# verifica completa headless in un comando (controlla ogni script, importa, avvia, esegue 2 suite)
bash verify.sh

# solo una suite
"$GODOT" --headless --path . --script res://tests/test_world.gd     # 29 controlli
"$GODOT" --headless --path . --script res://tests/test_gameplay.gd   # 77 controlli

# rendering reale: richiede una GPU e una finestra (non headless)
"$GODOT_GUI" --path . --script res://tests/test_visual.gd            # 8 controlli
"$GODOT_GUI" --path . --script res://tests/capture.gd                # 7 PNG in out/

# misure, senza asserzioni (stampa numeri)
"$GODOT" --headless --path . --script res://tests/perf.gd
```

Ogni suite è uno script `extends SceneTree` che esce con **exit code 0 = tutto verde, 1 = almeno un
controllo fallito** e stampa un riepilogo finale (`checks: N   failures: 0`). Un `print` senza
asserzione non è una verifica.

`verify.sh` usa le variabili `GODOT` / `GODOT_GUI`; se non sono impostate prova i percorsi comuni e
si ferma con un messaggio chiaro.

---

## 8. Stato reale dello sviluppo

Legenda dei livelli usata in tutto il pacchetto:

- **VERIFICATO** — eseguito e confrontato con l'atteso (exit code o stato osservato prima/dopo).
- **ESEGUITO** — lanciato, output visto, nessuna asserzione sul comportamento.
- **PARZIALE** — implementato, ma coperto solo in parte o solo in condizioni favorevoli.
- **PIANIFICATO** — non implementato.
- **NON FUNZIONANTE / BLOCCANTE** — noto rotto.

| Area | Stato | Prova |
|---|---|---|
| Generazione mondo, biomi, props, rovine, spawn sicuro | **VERIFICATO** | `test_world` — 29 controlli |
| Determinismo su seed e stream RNG separati | **VERIFICATO** | `test_world` + `test_gameplay` (hash del layout) |
| Movimento, collisioni, acqua non calpestabile | **VERIFICATO** | `test_gameplay` (dx = 29 px in 24 frame, blocco sul prop) |
| Combattimento melee, danno, knockback, morte/respawn | **VERIFICATO** | `test_gameplay` (144 → 137, knockback 96,7) |
| Due nemici, FSM, inseguimento, stallo | **VERIFICATO** | `test_gameplay` (69 → 9 px) |
| IA attorno a muri lunghi / vicino all'acqua | **PARZIALE** | non testata (buco dichiarato) |
| Loot, XP, livelli, inventario, equipaggiamento | **VERIFICATO** | `test_gameplay` (livello +1, max HP +12) |
| NPC, dialogo, braciere, ricompense | **VERIFICATO** | `test_gameplay` (dialogo 4 battute, cura 116 → 144) |
| HUD, pausa, morte, rigenerazione senza perdere progressione | **VERIFICATO** | `test_gameplay` |
| Rendering, atmosfera, due silhouette, notte | **VERIFICATO** con GPU | `test_visual` — 8 controlli falsificabili |
| Mira col mouse end-to-end, feel, FPS reali | **ESEGUITO / non asserito** | buco dichiarato (`CHECKPOINT.md` §7) |
| Audio | **PIANIFICATO** (0 %) | — |
| Salvataggio su disco | **PIANIFICATO** | — |
| Streaming a chunk, nemico a distanza, opzioni, export | **PIANIFICATO** | — |

Nessuna voce del pacchetto è nello stato **NON FUNZIONANTE**: il gioco si avvia, le suite passano,
le lacune sono per assenza di funzionalità, non per rotture.

---

## 9. Problemi noti e funzionalità mancanti

**Mancanti (non implementate, con criterio di accettazione in `CHECKPOINT.md` §6):**

1. **Audio: assente al 100 %** (P1). Il vincolo è "nessun asset audio importato", non "nessun
   audio": andrebbe generato con `AudioStreamGenerator`/`AudioStreamWAV`.
2. **Salvataggio su disco: assente** (P1). La progressione sopravvive solo nella sessione.
3. **Streaming a chunk: non implementato** (P2), benché il generatore sia già organizzato per celle
   e con stream RNG separati.
4. **Nemico a distanza: assente** (P2).
5. **Feedback di combattimento** (numeri di danno, hit-stop): assente (P3).
6. **UX inventario**: 12 slot reali ma la UI ne mostra 8, senza scroll/confronto (P3).
7. **Opzioni e accessibilità** (rimappatura, scala testo, palette per daltonismo): assenti (P4).
8. **Export e CI**: nessun preset, nessuna pipeline (P5).

**Limiti noti di ciò che c'è:**

- IA **locale**, non pathfinding globale: bersagli dietro un muro lungo possono richiedere tempo.
- Nessuna collisione fisica player↔nemico (distanza di rispetto): non si possono "spingere" i nemici.
- Rigenerazione del mondo = hitch di ~170–270 ms senza schermata di caricamento.
- Notte fino a 0,54 di luminanza con torcia additiva: non è un sistema di luce con ombre.
- Bilanciamento derivato da ragionamento, **non da playtest**.
- Testo di gioco in inglese hardcoded: nessuna tabella di localizzazione.
- `game.gd` (477 righe) è il composition root e cresce: loot/respawn/interazione sono candidati
  all'estrazione.

**Buchi di verifica (non affermare il contrario):** mira col mouse end-to-end, feel umano,
FPS con rendering reale (profilato solo headless), IA attorno a muri lunghi o vicino all'acqua,
overflow dell'inventario, distribuzione statistica dei drop, `--seed` end-to-end, sessioni lunghe
(memoria/leak), accessibilità. Elenco completo: `CHECKPOINT.md` §7.

---

## 10. Debiti tecnici e limiti del pacchetto

- Il progetto **non è mai stato in un repository Git** prima dell'archiviazione: la storia parte
  dal commit iniziale di questo pacchetto. Il checkpoint precedente era un archivio tar in
  `G-DEV/checkpoints/` (ora nel backup di sessione, vedi `CHECKPOINT.md` §11).
- Nessuna licenza è stata definita dall'autore: **prima di pubblicare il repository va scelta una
  licenza** (il motore Godot è MIT, ma il codice del gioco non ha licenza dichiarata).
- Le sonde visive scrivono in `out/`, che è escluso dall'import Godot con `.gdignore`. Gli
  screenshot prodotti non sono deterministici byte-per-byte (animazioni dipendenti dal tempo).
- Il progetto dichiara `config/features = "4.7"`: con una minor diversa l'API va verificata prima
  di usarla.

---

## 11. Riprendere lo sviluppo

1. Leggi `CHECKPOINT.md` §1–§3 (stato in una riga, ripresa in 60 secondi, mappa del codice).
2. Esegui `bash verify.sh`: se è rosso, il pacchetto non corrisponde al disco → fermati e diagnosti,
   non "aggiustare" i test.
3. Ricalcola l'impronta di §4: se differisce da quella registrata, qualcosa è cambiato dopo
   l'archiviazione.
4. Scegli **una** voce P1 di `CHECKPOINT.md` §6, scrivi prima il test che deve fallire, poi
   l'implementazione, poi aggiorna README e CHECKPOINT.
5. Vincoli da rispettare: GDScript tipizzato, logica senza nodi, segnali verso l'alto, determinismo
   su seed, nessun asset esterno, un solo passo logico per diff.

---

## 12. Licenza e attribuzioni

- **Codice del gioco**: nessuna licenza dichiarata (tutti i diritti riservati all'autore). Da
  decidere prima della pubblicazione.
- **Motore**: Godot Engine 4.7.2, licenza MIT (© Godot Engine contributors).
- **Asset di terze parti**: nessuno. Ogni pixel è generato dal codice del progetto.

---

## 13. Come è stato prodotto questo pacchetto

Archiviazione del 20 ottobre 2026: il progetto è stato copiato dalla directory di sviluppo,
private della cache `.godot/`, dei log di sessione e della directory `tools/` (vuota), quindi
sottoposto a verifica indipendente in questa stessa sede (import, avvio headless, suite headless).
I risultati di quella verifica sono in `CHECKPOINT.md` §10. Il backup integrale dello stato
pre-archiviazione è indicato in `CHECKPOINT.md` §11.
