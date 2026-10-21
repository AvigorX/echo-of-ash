# CHECKPOINT — Echoes of Ash

> **Consegna per la prossima sessione.** Questo file descrive lo stato *reale* del
> progetto: cosa è completo e verificato, cosa è parziale, cosa manca, come riprendere
> e quali trappole non ripetere. Non contiene piani non eseguiti presentati come fatti.

| | |
|---|---|
| Progetto | pacchetto `ECHO-OF-ASH/` (archivio G-DEV, 20/10/2026) |
| Percorso originale | `C:\Users\Dave\PROGETTI\G-DEV\projects\echoes-of-ash` (rimosso dopo l'archiviazione) |
| Motore | Godot `4.7.2.stable.official.ed1daf0bf` (percorso dell'eseguibile: variabile `GODOT`) |
| Data del checkpoint | 19 ottobre 2026, 07:00 (stato del codice) · riverificato il 20 ottobre 2026 |
| Codice | 22 script di gioco (3.504 righe) + 6 script di test (1.276 righe) |
| Impronta del codice | `sha256 1369dae8d93ee51a330aeebf55ac817ee576d0eaf8ccec32006283d98f0545fe` |
| Evidenze | screenshot in `out/` · numeri delle suite in §10 (i log storici sono stati rimossi: ridondanti) |
| Versione | **vertical slice giocabile** — 114 controlli (106 headless + 8 visivi), tutti verdi il 20/10/2026, 0 errori motore |

Come ricalcolare l'impronta (dalla cartella del progetto):

```bash
find . -path ./.godot -prune -o \( -name '*.gd' -o -name '*.tscn' -o -name 'project.godot' \) -print \
  | sort | xargs sha256sum | sha256sum
```

---

## 1. Stato in una riga

Il gioco si avvia, genera un mondo deterministico, si esplora con WASD + mouse, si
combatte contro due tipi di nemici, si raccoglie loot, si sale di livello, si parla con
un NPC, si usa un braciere, si muore e si rinasce, si mette in pausa e si rigenera il
mondo **senza perdere la progressione**. Tutto disegnato dal codice, nessun asset
importato, nessuna rete. Manca audio, salvataggio su disco e streaming a chunk.

---

## 2. Riprendere in 60 secondi

```bash
cd /percorso/ECHO-OF-ASH
export GODOT=/percorso/Godot_v4.7.2-stable_win64_console.exe   # variante _console: stampa su stdout
export GODOT_GUI=/percorso/Godot_v4.7.2-stable_win64.exe       # finestra reale (serve GPU)

# giocare (finestra reale, Vulkan)
"$GODOT_GUI" --path .
"$GODOT_GUI" --path . -- --seed 424242

# verifica completa (exit 0 = tutto ok: check-only su ogni script + import + avvio + 2 suite)
bash verify.sh

# suite singole
"$GODOT" --headless --path . --script res://tests/test_world.gd      # 29 controlli
"$GODOT" --headless --path . --script res://tests/test_gameplay.gd   # 77 controlli
"$GODOT_GUI" --path . --script res://tests/test_visual.gd            # 8 controlli (serve GPU)
"$GODOT" --headless --path . --script res://tests/perf.gd            # numeri, non pass/fail
"$GODOT_GUI" --path . --script res://tests/capture.gd                # 7 screenshot in out/
```

**Da leggere prima di toccare il codice:** `README.md` (architettura e stato),
`docs/ARCHITECTURE-EN.md` (specifica originale), §8 di questo file (trappole).

---

## 3. Mappa del codice

| File | Righe | Responsabilità | Testabile headless |
|---|---:|---|---|
| `scripts/world/world_data.gd` | 200 | griglia, query, hash del layout, guardia terraferma | **sì, puro** |
| `scripts/world/world_generator.gd` | 480 | generazione (rumore, soglie, POI, BFS, rovine, props, entità) | **sì, puro** |
| `scripts/world/ground_texture.gd` | 111 | `Image` → `ImageTexture` del suolo | sì (lento: ~165 ms) |
| `scripts/world/prop_visual.gd` | 156 | props + `StaticBody2D` opzionale | no (disegno) |
| `scripts/world/water_overlay.gd` | 65 | increspature/foam animate | no |
| `scripts/world/fog_layer.gd` | 58 | nebbia da texture radiale generata | no |
| `scripts/world/light_layer.gd` | 57 | glow additivo (torcia + bracieri) | no |
| `scripts/player/player.gd` | 258 | movimento, attacco, salute, XP, inventario | parziale |
| `scripts/player/player_visual.gd` | 102 | silhouette, idle/walk/attack, morte | no |
| `scripts/enemies/enemy.gd` | 334 | FSM, steering a raycast, stallo, danno, morte | parziale |
| `scripts/enemies/enemy_visual.gd` | 138 | due silhouette, telegrafo, barra vita | no |
| `scripts/combat/combat.gd` | 37 | risoluzione melee ad arco (pura) | **sì, puro** |
| `scripts/combat/effects.gd` | 95 | fendenti, particelle, anelli | no |
| `scripts/items/item_db.gd` | 67 | definizioni oggetti | **sì, puro** |
| `scripts/items/inventory.gd` | 131 | inventario + equipaggiamento | **sì, puro** |
| `scripts/items/pickup.gd` | 71 | oggetto raccoglibile + icona procedurale | no |
| `scripts/interact/interactable.gd` | 18 | contratto di interazione | sì |
| `scripts/interact/npc.gd` | 73 | Wanderer + dialogo + ricompensa | parziale |
| `scripts/interact/brazier.gd` | 70 | cura, cooldown, punto di respawn | sì |
| `scripts/systems/game.gd` | 477 | composition root: mondi, loot, respawn, input, pausa | **sì** |
| `scripts/systems/day_night.gd` | 52 | ciclo giorno/notte (`CanvasModulate`) | sì |
| `scripts/ui/hud.gd` | 454 | tutta la UI in codice | parziale |
| `tests/test_world.gd` | 196 | 29 controlli sul generatore | — |
| `tests/test_gameplay.gd` | 535 | 77 controlli end-to-end | — |
| `tests/test_visual.gd` | 244 | 8 controlli di rendering falsificabili | — |
| `tests/capture.gd` | 150 | 7 screenshot | — |
| `tests/inspect_shots.gd` | 89 | mappa ASCII/palette degli screenshot | — |
| `tests/perf.gd` | 62 | misure CPU/nodi/memoria | — |

Segnali (contratti fra sistemi): `Player.health_changed/xp_changed/leveled_up/damaged/died/
attack_swing/inventory_changed/notified`, `Enemy.died/struck/health_changed`,
`Inventory.changed`, `HUD.resume_requested/new_world_requested`.

---

## 4. Completo e verificato

Legenda: **V** = verificato da un test con exit code o stato osservato; **E** = eseguito
con output visto ma senza asserzione.

| Requisito del mandato | Implementazione | Prova | Livello |
|---|---|---|---|
| Mondo procedurale con biomi coerenti | 5 ottave di rumore + soglie a percentile | `test_world` (acqua 22%, verde 61.6%, pietra 6.3%) | **V** |
| Alberi, rocce, arbusti, sentieri, rovine | 826 props, 35 muri, 294 celle di sentiero | `test_world` | **V** |
| Collision-aware placement | props solidi bloccano cella + spaziatura 3×3 | `test_world` (0 prop sull'acqua, 0 celle non bloccate) | **V** |
| Spawn sicuro | 11×11 celle libere | `test_world` + `test_gameplay` | **V** |
| Seed deterministico | stream separati per fase | stesso seed → stesso hash (2 generazioni + runtime) | **V** |
| Rigenerazione con seed diverso | `R` / menu / `--seed` | hash diverso, 24 nemici, player allo spawn | **V** |
| Stream RNG isolati | `make_stream(seed, id)` | indipendenza e riproducibilità | **V** |
| Movimento 8 direzioni + collisioni | `CharacterBody2D` + mask 1 | dx=29px in 24 frame, blocco sul prop | **V** |
| Camera con smoothing | `Camera2D` figlia, limiti mondo | camera attiva e limiti impostati | **E** |
| Animazioni idle/walk/attack procedurali | `player_visual.gd` | pixel ciano presenti solo se visibile | **V** |
| Salute, danno, knockback, morte/respawn | `player.take_damage`, `respawn` | 144 → 137 da mischia, morte + `E` | **V** |
| Melee + feedback | arco 105°, particelle, shake | danno 26→19, knockback 96.7 | **V** |
| Due nemici distinti | crawler + warden | entrambi disegnati (diff pixel) | **V** |
| Stati IA (idle/patrol/chase/attack/hurt/death) | FSM `Enemy.State` | inseguimento 69→9 px, standoff, danno subito | **V** |
| Rilevamento + LOS | raggio fisico | chase avviene solo con vista libera | **E** (indiretta) |
| Movimento obstacle-aware, non incastrato | 7 raggi + sidestep 0.85 s | non compenetra props su 180 frame | **V** (parziale: solo campo aperto) |
| Loot + respawn nemici | probabilità + ancora 28 s | Warden ≥ 2 shard; respawn a 1371 px | **V** |
| XP, livelli, HP/danno crescenti | curva + bonus | livello +1, max HP +12 | **V** |
| Inventario + 5 oggetti + equipaggiamento | `Inventory`, 3 slot | pozzo cura, arma +4, armatura +2, amuleto +20 | **V** |
| Drop casuali controllati | tabella per tipo | loot garantito del Warden | **V** (parziale: no statistica) |
| Risorse collezionabili | ash shard (+2 XP) | raccolta con `E` (0→3) | **V** |
| Progressione persistente in sessione | player riusato alla rigenerazione | livello e shard invariati, stesso instance id | **V** |
| Oggetti interattivi + NPC + dialogo | `Interactable`, `Npc` | dialogo 4 battute, ricompensa una volta | **V** |
| Cura/resource interaction | braciere 35 HP, 12 s | 116→144, cooldown 12 | **V** |
| Prompt chiari | HUD prompt contestuale | `[E] Pick up Ash Shard x3` visibile | **V** |
| HUD completa | barre, XP, livello, notifiche, inventario, pausa, morte, guida | toggle `I`, `ESC`, pulsanti Resume/New world | **V** |
| Controlli mostrati nella UI | guida a 3 righe | testo presente, binding verificati | **V** |
| Atmosfera | acqua animata, nebbia, luci, giorno/notte, particelle, vignetta | diff pixel: nebbia 25k, notte 0.264→0.138, acqua animata | **V** |
| Zero asset importati | tutto generato | `find` senza PNG/TTF esterni; `out/` ha `.gdignore` | **V** |
| Nessuna rete | nessun riferimento | `grep -rniE "http|socket|..."` → 0 | **V** |
| README con setup/controlli/architettura/seed/test | `README.md` | questo checkpoint | **V** |
| Avvio riproducibile | scena singola + seed di default | harness exit 0 | **V** |

---

## 5. Completo ma con limiti noti (non rifare da zero, semmai migliorare)

1. **IA locale, non pathfinding globale.** Raycast + sidestep evitano ostacoli vicini; un
   bersaglio dietro un muro lungo può richiedere tempo. Scelta deliberata (niente
   `NavigationServer` in headless). Se serve: A* su `WorldData` (la griglia c'è già) e
   waypoint verso il player.
2. **Nessuna collisione fisica player↔nemico.** Il nemico mantiene una distanza di
   rispetto (`radius + 5 + 1`) e colpisce entro `attack_range`. Semplifica il knockback,
   ma non permette di "spingere" i nemici.
3. **Rigenerazione = hitch di ~170–270 ms** (mondo + texture) senza schermata di
   caricamento. Accettabile nel prototipo; da mascherare con un fade/loading se si allunga.
4. **Inventario**: 12 slot reali, la UI ne mostra 8; niente scroll, drag, confronto oggetti.
5. **Notte** scurisce fino a 0.54 di luminanza con torcia additiva: leggibile, ma non è
   un sistema di luce con ombre/occlusione.
6. **Bilanciamento** derivato da ragionamento, non da playtest: 100 HP, 7 danni, 26/72 HP
   nemici, respawn 28 s.
7. **Testo in inglese hardcoded** negli script (`hud.gd`, `npc.gd`, `pickup.gd`): nessuna
   tabella di localizzazione.
8. **`game.gd` è il composition root e cresce** (477 righe): loot, respawn e interazione
   sono candidati all'estrazione quando si aggiungono sistemi.

---

## 6. Cosa manca (in ordine di priorità, con criterio di accettazione)

### P1 — Audio procedurale (assente al 100%)
Nessun suono. Il mandato vieta asset audio importati, non l'audio: va generato.
- File: nuovo `scripts/systems/audio.gd` (autoload **no**: nodo figlio di `Game`), bus
  generati con `AudioStreamGenerator` o `AudioStreamWAV` costruito da `PackedByteArray`.
- Suoni minimi: passo, fendente, colpo a segno, morte nemico, raccolta, cura, livello.
- **Accettazione:** test headless che verifica `player_streams_created >= 6` e che ogni
  suono abbia `get_length() > 0`; nessun file in `res://` oltre a `.gd/.tscn`.

### P1 — Salvataggio versionato
- File: `scripts/systems/save_game.gd` con `save()/load()` su `user://save.json`,
  `{"version": 1, "seed": …, "player": {level, xp, base_max_health, base_damage, health},
  "inventory": {items, equipped}, "respawn_point": [x, y]}`.
- Validazione: versione sconosciuta o JSON malformato → nessun crash, si parte da zero.
- **Accettazione:** test headless che salva, azzera lo stato, carica e confronta i campi;
  file corrotto → fallback pulito con un warning.

### P1 — Test IA attorno alle rovine (chiude il buco di verifica più grosso)
- Scenario: nemico dietro l'angolo di un muro di rovina, player dall'altra parte a ~80 px.
- **Accettazione:** in ≤ 6 s la distanza cala di almeno 30 px **oppure** il nemico cambia
  almeno 3 volte direzione (prova che sta aggirando, non bloccato). Deterministico: niente
  `randf()` reale, usare il seed del mondo.

### P2 — Streaming a chunk (richiesto "designed for", non implementato)
- `WorldGenerator` ha già funzioni per-cella e stream separati: estrarre
  `terrain_at_world(seed, cell)` e generare chunk 32×32 attorno alla camera.
- **Accettazione:** con player in movimento per 60 s il conteggio nodi resta sotto 2500 e
  il terreno ai bordi del chunk coincide con quello generato dall'altra parte (`hash`
  per cella).

### P2 — Nemico a distanza + telegrafo
- Terzo tipo "Ember Wisp": proiettile come `Area2D` **oppure** query a tempo (coerente con
  `combat.gd`), danno 12, windup 0.6 s, movimento a distanza 90 px.
- **Accettazione:** test che verifica danno al player a 100 px e nessun danno se il player
  esce dal raggio durante il windup.

### P3 — Feedback di combattimento
- Numeri di danno fluttuanti (`draw_string` con `ThemeDB.fallback_font`, verificare prima
  con `tools/godot-docs-search.py check ThemeDB.fallback_font`), hit-stop 2–3 frame.
- **Accettazione:** screenshot diff che mostra i numeri; test che il hit-stop dura ≤ 3 frame.

### P3 — UX inventario
- Scroll o paginazione per 12 slot, descrizione a comparsa, confronto con l'equipaggiato.
- **Accettazione:** test che riempie 12 slot e verifica che l'ultimo sia raggiungibile.

### P4 — Opzioni e accessibilità
- Rimappatura input in UI, intensità shake, palette alternativa per daltonismo, scala testo.
- **Accettazione:** le impostazioni sopravvivono al riavvio (dipende dal salvataggio).

### P5 — Export e CI
- Preset Windows/Linux, job che esegue harness + `test_world` + `test_gameplay`.
- **Accettazione:** build esportata che si avvia e scrive un log; CI verde.

### P6 — Pulizia
- Estrarre da `game.gd`: `loot_table.gd`, `respawn_system.gd`, `interaction_system.gd`.
- Tabelle stringhe UI in una risorsa, per la localizzazione.

---

## 7. Buchi di verifica (cosa NON è provato — non affermare il contrario)

1. **Mira col mouse end-to-end**: `Player.aim_direction()` non è testata con un mouse reale;
   i test chiamano `try_attack(dir)`. Il binding LMB è verificato solo nella InputMap.
2. **Feel umano**: nessun playtest con tastiera/mouse reali; velocità, portata del fendente,
   cooldown e densità dei nemici non sono tarati su sensazioni.
3. **FPS con rendering reale**: misurato solo headless (`perf.gd`); le draw call vere non
   sono state profilate. `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` in headless è 0.
4. **IA attorno a muri lunghi/angoli** (§6 P1) e **IA vicino all'acqua** (la guardia
   terraferma è testata sul player, non sui nemici).
5. **Overflow inventario** (12 slot pieni) e comportamento dei pickup a terra.
6. **Distribuzione statistica dei drop** (solo il loot garantito del Warden è asserito).
7. **`--seed` da riga di comando end-to-end**: verificato solo il parser
   (`Game.seed_from_args`), non un avvio reale con l'argomento.
8. **Sessioni lunghe**: nessun test di memoria/leak oltre i 240 frame di `perf.gd`.
9. **Accessibilità**: contrasto, scala testo, rimappatura, pausa reale con `process_mode`
   sono implementati ma non misurati.
10. **Audio**: non esiste, quindi non c'è nulla da verificare.
11. **Salvataggio**: non esiste.
12. **Giudizio estetico**: le immagini sono verificate solo per statistiche (colori,
    luminanza, diff); la qualità visiva va guardata da un umano (`out/*.png`).

---

## 8. Trappole misurate in questo ambiente (non ripeterle)

1. **`RandomNumberGenerator.state = 0` annulla il seed.** Impostare solo `rng.seed`.
   Sintomo: seed diversi producevano lo stesso `layout_hash`. Costato un test fallito.
2. **`Area2D` rileva l'overlap solo dal 3° frame fisico dopo un teletrasporto.** Per questo
   il melee è un arco interrogato e non un'`Area2D`. Non reintrodurre `Area2D` nei test.
3. **Screenshot**: `root.get_texture().get_image()` può restituire un'immagine **più grande
   della finestra** (misurato 4320×2430 con finestra 1440×810). Normalizzare con
   `img.resize(480, 270, INTERPOLATE_NEAREST)` prima di confrontare i pixel, altrimenti le
   coordinate non tornano e i diff valgono 0.
4. **`get_global_transform_with_canvas().origin` è in coordinate viewport** (480×270), non
   in pixel finestra.
5. **Diff visivo generico instabile** su sprite scuri: usare un colore-firma (il ciano del
   trim) che deve valere 0 quando l'elemento è nascosto.
6. **WASAPI**: all'avvio compare `audio_device_init error … falling back to dummy driver`.
   È ambientale (nessun endpoint audio nella sessione), non un errore del gioco.
7. **Input nei test**: `Input.action_press/release` per il movimento;
   `Input.parse_input_event(InputEventKey)` per passare da `_unhandled_input` (pausa,
   interagisci, inventario). `InputEventAction` non è usato: meglio eventi di tasto reali.
8. **`--check-only` dopo aver aggiunto un `class_name`**: eseguire prima `--import`, che
   aggiorna `.godot/global_script_class_cache.cfg`.
9. **L'acqua non ha corpi fisici**: la guardia è in `WorldData.resolve_land_position`, chiamata
   da player e nemici dopo `move_and_slide`. Se si aggiunge un nuovo attore mobile, va
   chiamata anche lì.
10. **Regenerazione e UI**: `start_world()` chiama `hud.reset_overlays()`; senza, il menu di
    pausa resta aperto e blocca l'input (bug trovato da un test).
11. **Path MSYS**: passare a Godot path `C:/...` (via `cygpath -m`), non `/c/...`.

---

## 9. Convenzioni da rispettare

- **GDScript tipizzato** ovunque (`var x: Vector2`, `func f() -> void`); un errore di tipo
  deve emergere con `--check-only`.
- **Commenti e docstring in italiano tecnico**, identificatori e testi di gioco in inglese.
- **Separazione**: dati/logica senza nodi (`WorldData`, `WorldGenerator`, `Inventory`,
  `ItemDB`, `Combat`) · presentazione (`*_visual.gd`, `effects.gd`, `hud.gd`) · composizione
  (`game.gd`). La logica non deve MAI leggere nodi né il disegno decidere lo stato.
- **Segnali verso l'alto**, nessun `get_node("../../..")`, nessun autoload.
- **Determinismo**: ogni decisione casuale passa da un `RandomNumberGenerator` con seed
  esplicito. Niente `randi()`/`randf()` globali.
- **Ogni nuovo comportamento = un test con exit code.** Un `print` senza asserzione non è
  una verifica.
- **Un solo passo logico per diff**, e aggiornare i numeri nel `README.md` (conteggi dei
  test) ogni volta che la suite cambia.
- **Nessun asset esterno**: se serve un suono/immagine, lo si genera.

---

## 10. Registro delle evidenze

**Verifica eseguita il 20 ottobre 2026, sul pacchetto di archivio** (Godot 4.7.2, Windows,
impronta del codice invariata: `1369dae8…`):

| Comando | Esito | Dettaglio |
|---|---|---|
| `bash verify.sh` | **0** | 28 script `--check-only` ok · import ok · avvio headless ok · `test_world` 29 passati / 0 falliti · `test_gameplay` 77 passati / 0 falliti · 0 `SCRIPT ERROR` |
| `test_visual.gd` (GUI, GPU reale) | **0** | 8 passati / 0 falliti: viewport 480×270, giocatore (14 px ciano visibili / 0 nascosto), due nemici (306 px), HUD (943 px), nebbia (26.520 px), fendente (2.436 px), notte 0,264 → 0,145, acqua animata (576 px) |
| `perf.gd` (headless, numeri) | **0** | generazione **226,6 ms** · texture 1536×1536 **183,7 ms** · **1.869 nodi** · 3.969 oggetti · **59,1 MB** · `_process` 14,50 ms · fisica 32,66 ms · 60,0 fps · 24 nemici · 18 pickup · stress 38 nemici 59,9 fps |
| `capture.gd` (GUI) | **non rieseguito** | ultima esecuzione 19/10: 7 PNG (`out/shot_01…07`) |
| `inspect_shots.gd` | **non rieseguito** | sonda di ispezione degli screenshot |

Verifica precedente (19/10/2026, progetto originale): 28 script ok, harness exit 0, `test_world`
29/0, `test_gameplay` 77/0, `test_visual` 8/0 (3 esecuzioni consecutive identiche), `perf` come
sopra con generazione 167 ms, `capture` 7 PNG da 1,2k–3,3k colori.

I log completi di quella sessione (`out/logs/{harness,test_world,test_gameplay,test_visual,perf,capture}.log`)
sono stati **rimossi dal pacchetto** perché ridondanti rispetto a questa tabella; si trovano nel
backup di sessione (§11).

Mondo di default (seed 20261019, misurato il 19/10 e non modificato: impronta del codice identica):
hash `676752547`, spawn `(48,48)`, 826 props (452 solidi), 24 nemici, 18 oggetti, 6.737 celle
calpestabili, connettività 99,1%.

---

## 11. Rollback e backup

Il progetto **ora è un repository Git** (inizializzato durante l'archiviazione del 20/10/2026;
prima non lo era). Storia: un solo commit iniziale con lo stato verde del 19/10/2026. Il vecchio
checkpoint tar (`checkpoints/echoes-of-ash_20261019_0700.tar.gz`) **non è più dentro il progetto**:
è conservato nel backup di sessione.

| | |
|---|---|
| Backup di sessione | `C:\Users\Dave\PROGETTI\G-DEV-BACKUP-2026-10-20\` |
| Contenuto | `echoes-of-ash-project-20261020.tar.gz` (progetto pre-archiviazione, con `.godot/`, `out/logs/` e `tools/`) · `checkpoints-20261020.tar.gz` (contiene il vecchio `echoes-of-ash_20261019_0700.tar.gz` + `.sha256`) · archivi degli altri progetti della sessione |
| Integrità | `SHA256SUMS.txt` accanto agli archivi; ognuno verificato con `tar tzf` |

Ripristino:

```bash
# 1. file singolo dal backup di sessione
tar -xzf G-DEV-BACKUP-2026-10-20/echoes-of-ash-project-20261020.tar.gz -C <destinazione> ./out/logs/test_gameplay.log

# 2. stato del 19/10/2026 (checkpoint tar originale, dentro l'archivio dei checkpoint)
tar -xzf G-DEV-BACKUP-2026-10-20/checkpoints-20261020.tar.gz
sha256sum -c checkpoints/echoes-of-ash_20261019_0700.tar.gz.sha256

# 3. stato del commit archiviato (dal repository)
git checkout -- .
```

**Prima di ogni modifica sostanziale**: commit dello stato verde corrente (o un nuovo archivio tar
con data/ora nel nome, fuori dal repository). Il commit è preferibile: è diff-abile e non duplica
900 KB a ogni passo.

---

## 12. Prima azione consigliata per la prossima sessione

1. Eseguire i cinque comandi di §2 e pretendere exit 0 (se qualcosa è rosso, il checkpoint
   non corrisponde al disco: fermarsi e capire, non "aggiustare" i test).
2. Ricalcolare l'impronta di §0: se differisce, qualcuno ha modificato il codice dopo
   questo report.
3. Scegliere **una** voce P1 di §6, scrivere prima il test che deve fallire, poi
   l'implementazione, poi aggiornare `README.md` e questo file.
