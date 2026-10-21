# Echoes of Ash

Vertical slice of a 2D procedural action RPG, written in **GDScript** for **Godot 4.7.2**.
No imported assets: terrain, props, characters, effects, UI and atmosphere are drawn by the
code. No networking, no external services.

This repository is the project's **archive package**: it contains everything needed to build,
run, verify and pick it up again. Session reports, logs and temporary artifacts have been
removed; the unique data has been moved into [`CHECKPOINT.md`](CHECKPOINT.md). The original
technical specification (in English) is in [`docs/ARCHITECTURE-EN.md`](docs/ARCHITECTURE-EN.md).

---

## 1. Vision and goals

A "small but complete" action RPG: an island generated from a seed, free exploration with
8-direction movement, real-time melee combat, two enemy types, loot, character growth, an NPC
with dialogue and a brazier as a heal/respawn point. The project constraint is
**zero external assets**: everything you see is procedural `_draw()` or `Image`/`ImageTexture`
generated at runtime.

The stated goal was to demonstrate the *vertical slice* (one complete and coherent playthrough),
not the amount of content. The project is **frozen** in this state: see §9 and §12.

---

## 2. Gameplay and features present

Everything below is **implemented and verified** by a test with an exit code or by an observed
state (details in the table of §9 and in `CHECKPOINT.md` §4).

- **Deterministic procedural world**: an island from elevation + moisture noise with
  percentile thresholds (≈22 % water, ≈78 % land), 6 ground biomes, 4 points of interest linked
  by BFS paths, 2 ruin complexes with solid walls and openings, ~800 props with minimum spacing.
  Guaranteed safe spawn (clear 11×11 area).
- **Determinism on seed**: separate RNG streams for terrain, props, entities and loot
  (`WorldGenerator.make_stream(seed, id)`); same seed → same `layout_hash`.
- **Player**: `CharacterBody2D`, 8-direction movement with acceleration/friction, collisions
  with solid props, water that cannot be walked on (sliding along the shore), camera with
  smoothing and world limits.
- **Combat**: 105° arc slash, 26 px reach, knockback, particles, screen shake.
- **Two distinct enemies** (crawler and warden) with an `idle / patrol / chase / attack / hurt /
  death` FSM, radius detection with line of sight, obstacle-aware movement (7 rays + sidestep),
  stall and recovery, respawn at an anchor after 28 s.
- **Progression**: XP, levels, growing HP and damage, death and rebirth, progression preserved
  when the world is regenerated (the player node is reused).
- **Items**: 5 items, 12-slot inventory with 3 equipment slots, controlled drops,
  pickup with `E`, use with `1`–`4`.
- **Interaction**: `Interactable` contract, "Wanderer" NPC with a 4-line dialogue and a one-time
  reward, brazier that heals 35 HP with a 12 s cooldown and acts as a respawn point.
- **Complete UI in code** (`CanvasLayer`): HP/XP bars, level, notifications, contextual prompt,
  inventory, pause (Resume / New world), death screen, control guide.
- **Atmosphere**: animated water, radial fog, additive glow (torch + braziers), day/night cycle
  with `CanvasModulate`, vignette.

**Missing by choice or by state of progress**: audio (0 %), on-disk save, chunk streaming,
ranged enemies, options/accessibility, export and CI. See §10.

---

## 3. Architecture and technologies

A clean split into three layers, with the logic runnable without rendering:

| Layer | Files | Rule |
|---|---|---|
| **Data + logic** (no nodes) | `world/world_data.gd`, `world/world_generator.gd`, `items/item_db.gd`, `items/inventory.gd`, `combat/combat.gd`, `interact/interactable.gd` | pure or nearly pure functions, headless-testable |
| **Presentation** | `*_visual.gd`, `effects.gd`, `ground_texture.gd`, `water_overlay.gd`, `fog_layer.gd`, `light_layer.gd`, `ui/hud.gd` | reads state, does not decide it |
| **Composition** | `systems/game.gd` | composition root: worlds, loot, respawn, input, pause |

- Communication **by signals upwards** (`Player.health_changed/damaged/died/…`,
  `Enemy.died/struck/health_changed`, `Inventory.changed`, `HUD.resume_requested/new_world_requested`).
  No `get_node("../../..")`, no autoload.
- All randomness goes through a `RandomNumberGenerator` with an explicit seed; no global
  `randi()` / `randf()`.
- Single scene: `scenes/main.tscn` (a `Node2D` with `scripts/systems/game.gd`). Everything else is
  built at runtime.
- Melee is a **queried arc**, not an `Area2D`: a deliberate choice, because `Area2D` detects
  overlap only from the third physics frame after a teleport (measured trap, `CHECKPOINT.md` §8).

---

## 4. Versions and dependencies

| | |
|---|---|
| Engine | **Godot 4.7.2.stable.official** (`ed1daf0bf`) — no addons, no plugins |
| Declared `config/features` | `PackedStringArray("4.7")` |
| Language | Typed GDScript, 22 game scripts (3,504 lines) + 6 test scripts (1,276 lines) |
| External assets | **none** (no images, no fonts, no audio) |
| Networking | no calls, no telemetry |
| Code fingerprint | `sha256 1369dae8d93ee51a330aeebf55ac817ee576d0eaf8ccec32006283d98f0545fe` (computed over `*.gd`, `*.tscn`, `project.godot` only, excluding `.godot/`) |

Fingerprint recipe (from the package root):

```bash
find . -path ./.godot -prune -o \( -name '*.gd' -o -name '*.tscn' -o -name 'project.godot' \) -print \
  | sort | xargs sha256sum | sha256sum
```

---

## 5. Directory structure

```
ECHO-OF-ASH/
├── project.godot            configuration: main scene, InputMap, 480×270 ×3
├── scenes/main.tscn         single scene: Node2D root + game.gd
├── scripts/
│   ├── systems/             game.gd (composition root), day_night.gd
│   ├── world/               world_data, world_generator, ground_texture, prop/water/fog/light
│   ├── player/              player.gd (logic), player_visual.gd (drawing)
│   ├── enemies/             enemy.gd (FSM), enemy_visual.gd
│   ├── combat/              combat.gd (pure melee arc), effects.gd
│   ├── items/               item_db, inventory, pickup
│   ├── interact/            interactable (contract), npc, brazier
│   └── ui/                  hud.gd (the whole UI)
├── tests/                   test_world, test_gameplay, test_visual, capture, inspect_shots, perf
├── out/                     output of the visual probes (historical screenshots + `.gdignore`)
├── docs/
│   └── ARCHITECTURE-EN.md   original technical specification (English, full text)
├── README.md                this file
├── CHECKPOINT.md            operational continuity: state, traps, debts, resuming
└── INDEX.md                 index: where things are
```

`out/` contains `.gdignore`: Godot does not import the PNGs produced by the probes. The
`shot_01…07` screenshots are the visual evidence of the slice; the historical logs have been
removed (they were redundant with respect to `CHECKPOINT.md` §10).

---

## 6. Installation and launch

Prerequisite: Godot **4.7.2** (same minor). No other requirement.

```bash
# 1. path to the executable (adapt to your system)
export GODOT=/path/to/Godot_v4.7.2-stable_win64_console.exe   # on Windows: the _console variant
export GODOT_GUI=/path/to/Godot_v4.7.2-stable_win64.exe       # real window (audio/video)

# 2. first import (generates .godot/, required before --check-only and the suites)
"$GODOT" --headless --path . --import

# 3. play (1440×810 window, internal rendering 480×270 scaled ×3)
"$GODOT_GUI" --path .

# 4. world with a specific seed
"$GODOT_GUI" --path . -- --seed 424242
```

The project also opens from the Godot editor (`Import` → `project.godot`).
The first launch generates the world (≈250 ms) and the ground texture (≈250 ms).

**Note on paths**: on Windows, Godot wants native paths (`C:/...`), not `/c/...`. If you use an
MSYS/git-bash shell, convert with `cygpath -m "$PWD"`.

### In-game controls

| Input | Action |
|---|---|
| `W A S D` | 8-direction movement |
| mouse | slash aiming |
| left button | attack (105° arc, 26 px reach) |
| `E` | interact / pick up / advance the dialogue / get up when dead |
| `I` | inventory |
| `1` `2` `3` `4` | use or equip the item in that row |
| `ESC` | pause menu (Resume / New world) |
| `R` | regenerate the world with the next seed |

The current seed is shown in the HUD (`seed <n> · <phase>`). Default seed: `20261019`.

---

## 7. Tests and running the checks

```bash
# full headless verification in one command (checks every script, imports, launches, runs 2 suites)
bash verify.sh

# a single suite
"$GODOT" --headless --path . --script res://tests/test_world.gd     # 29 checks
"$GODOT" --headless --path . --script res://tests/test_gameplay.gd   # 77 checks

# real rendering: requires a GPU and a window (not headless)
"$GODOT_GUI" --path . --script res://tests/test_visual.gd            # 8 checks
"$GODOT_GUI" --path . --script res://tests/capture.gd                # 7 PNGs in out/

# measurements, without assertions (prints numbers)
"$GODOT" --headless --path . --script res://tests/perf.gd
```

Each suite is an `extends SceneTree` script that exits with **exit code 0 = all green, 1 = at least
one failed check** and prints a final summary (`checks: N   failures: 0`). A `print` without an
assertion is not a verification.

`verify.sh` uses the `GODOT` / `GODOT_GUI` variables; if they are not set it tries the common paths
and stops with a clear message.

---

## 8. Actual state of development

Legend of the levels used throughout the package:

- **VERIFIED** — run and compared against expectations (exit code or state observed before/after).
- **EXECUTED** — launched, output seen, no assertion on behaviour.
- **PARTIAL** — implemented, but covered only in part or only under favourable conditions.
- **PLANNED** — not implemented.
- **NOT WORKING / BLOCKING** — known broken.

| Area | State | Proof |
|---|---|---|
| World generation, biomes, props, ruins, safe spawn | **VERIFIED** | `test_world` — 29 checks |
| Determinism on seed and separate RNG streams | **VERIFIED** | `test_world` + `test_gameplay` (layout hash) |
| Movement, collisions, water that cannot be walked on | **VERIFIED** | `test_gameplay` (dx = 29 px in 24 frames, blocked by the prop) |
| Melee combat, damage, knockback, death/respawn | **VERIFIED** | `test_gameplay` (144 → 137, knockback 96.7) |
| Two enemies, FSM, chasing, stall | **VERIFIED** | `test_gameplay` (69 → 9 px) |
| AI around long walls / near water | **PARTIAL** | not tested (declared gap) |
| Loot, XP, levels, inventory, equipment | **VERIFIED** | `test_gameplay` (level +1, max HP +12) |
| NPC, dialogue, brazier, rewards | **VERIFIED** | `test_gameplay` (4-line dialogue, heal 116 → 144) |
| HUD, pause, death, regeneration without losing progression | **VERIFIED** | `test_gameplay` |
| Rendering, atmosphere, two silhouettes, night | **VERIFIED** with GPU | `test_visual` — 8 falsifiable checks |
| Mouse aiming end-to-end, feel, real FPS | **EXECUTED / not asserted** | declared gap (`CHECKPOINT.md` §7) |
| Audio | **PLANNED** (0 %) | — |
| On-disk save | **PLANNED** | — |
| Chunk streaming, ranged enemy, options, export | **PLANNED** | — |

No entry in the package is in the **NOT WORKING** state: the game launches, the suites pass,
and the gaps are due to missing features, not to breakage.

---

## 9. Known issues and missing features

**Missing (not implemented, with acceptance criteria in `CHECKPOINT.md` §6):**

1. **Audio: 100 % absent** (P1). The constraint is "no imported audio assets", not "no
   audio": it should be generated with `AudioStreamGenerator`/`AudioStreamWAV`.
2. **On-disk save: absent** (P1). Progression survives only within the session.
3. **Chunk streaming: not implemented** (P2), although the generator is already organised by cells
   and with separate RNG streams.
4. **Ranged enemy: absent** (P2).
5. **Combat feedback** (damage numbers, hit-stop): absent (P3).
6. **Inventory UX**: 12 real slots but the UI shows 8 of them, with no scroll/compare (P3).
7. **Options and accessibility** (remapping, text scale, colour-blind palettes): absent (P4).
8. **Export and CI**: no preset, no pipeline (P5).

**Known limits of what exists:**

- **Local** AI, not global pathfinding: targets behind a long wall may take time.
- No physical player↔enemy collision (personal space): enemies cannot be "pushed".
- World regeneration = ~170–270 ms hitch with no loading screen.
- Night down to 0.54 luminance with an additive torch: it is not a lighting system with shadows.
- Balancing derived from reasoning, **not from playtesting**.
- In-game text hardcoded in English: no localisation table.
- `game.gd` (477 lines) is the composition root and keeps growing: loot/respawn/interaction are
  candidates for extraction.

**Verification gaps (do not claim otherwise):** mouse aiming end-to-end, human feel,
FPS with real rendering (profiled headless only), AI around long walls or near water,
inventory overflow, statistical drop distribution, `--seed` end-to-end, long sessions
(memory/leaks), accessibility. Full list: `CHECKPOINT.md` §7.

---

## 10. Technical debt and limits of the package

- The project **was never in a Git repository** before archiving: history starts from the initial
  commit of this package. The previous checkpoint was a tar archive in
  `G-DEV/checkpoints/` (now in the session backup, see `CHECKPOINT.md` §11).
- No licence was defined by the author: **a licence must be chosen before publishing the
  repository** (the Godot engine is MIT, but the game code has no declared licence).
- The visual probes write into `out/`, which is excluded from the Godot import by `.gdignore`. The
  screenshots produced are not deterministic byte-for-byte (time-dependent animations).
- The project declares `config/features = "4.7"`: with a different minor the API must be verified
  before use.

---

## 11. Resuming development

1. Read `CHECKPOINT.md` §1–§3 (state in one line, resume in 60 seconds, code map).
2. Run `bash verify.sh`: if it is red, the package does not match the disk → stop and diagnose,
   do not "fix" the tests.
3. Recompute the fingerprint of §4: if it differs from the recorded one, something changed after
   archiving.
4. Choose **one** P1 item from `CHECKPOINT.md` §6, write the test that must fail first, then the
   implementation, then update README and CHECKPOINT.
5. Constraints to respect: typed GDScript, logic without nodes, signals upwards, determinism
   on seed, no external assets, one logical step per diff.

---

## 12. Licence and attributions

- **Game code**: no declared licence (all rights reserved to the author). To be decided before
  publication.
- **Engine**: Godot Engine 4.7.2, MIT licence (© Godot Engine contributors).
- **Third-party assets**: none. Every pixel is generated by the project code.

---

## 13. How this package was produced

Archiving of 20 October 2026: the project was copied from the development directory, stripped of
the `.godot/` cache, the session logs and the `tools/` directory (empty), then subjected to
independent verification in this same location (import, headless launch, headless suites).
The results of that verification are in `CHECKPOINT.md` §10. The full backup of the
pre-archiving state is indicated in `CHECKPOINT.md` §11.
