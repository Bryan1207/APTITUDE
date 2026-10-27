# Act 1 — Milestone 2: playable run prototype

## What is live

A single-player run starts with exactly **one of the four chosen heroes**.
Single Player confirmation creates a new `AptitudeAct1Run` instance and a
seeded map. The displayed seed is reproducible in engine tests.
The generator guarantees every node has a route from an earlier floor and a
connection to a later floor; floor counts and positions vary with each seed.

- **15 floors** (first floor: 3 options; later floors: 2–5 irregular nodes
  spread across 9 possible horizontal lanes), plus one mandatory boss.
  Routes connect only to the next floor and cannot be revisited.
- A **scrollable, dark, uncluttered blueprint map** keeps 15 floors legible
  rather than compressing everything into 900 pixels.
- Nodes are drawn in vector-like white chalk (combat = crossed swords, elite =
  skull, event = question mark, shop = dollar sign, rest = cross, boss = crown).
- Player-visited connections are colored with a broad, translucent yellow
  highlighter. Unvisited paths remain fine, faint white lines.
- The map and battle use one shared native Godot header, so layout and click
  targets cannot drift independently.
- **Floor 16** has a single mandatory Alextron Sentinel boss node.
- Map node choices: Combat, Elite, Rest, Shop, Event.
- Combat uses the existing FIFO card execution engine.
- Each accepted action immediately affects enemy/hero state.
- Finishing combat saves HP, max HP and coins. A non-boss victory requires
  one reward choice (add Attack, add Block, or heal 8).
- The player's deck persists between fights, including reward additions.
- Noncombat nodes resolve a choice and return to the connected map.

Run state is in `scripts/act1_run.gd`. UI transitions are orchestrated by
`scripts/main.gd` and drawn in `scripts/menu_flow.gd`. The combat engine is
`scripts/combat_engine.gd`.

## Approved passives

Passives are enabled via `combat.start([selected_id], encounter_id,
{"apply_passives": true, ...})`. They are deliberately **opt-in** so legacy
four-hero engine fixtures remain backward-compatible.

- Bryan: one Block at each combat start.
- Carlos: one bonus damage to his first *accepted* Attack in that encounter;
  invalid targets do not consume his bonus.
- Manny: draw six (instead of five) starting cards.
- Cristian & HB: two Block at each combat start.

## Difficulty

`scale_for_party=true` scales enemy HP and damage with party size. Current
multipliers are:

| Players | Enemy HP multiplier | Enemy damage multiplier |
|---|---:|---:|
| 1 | 0.60 | 0.50 |
| 2 | 0.73 | 0.66 |
| 3 | 0.86 | 0.82 |
| 4 | 0.99 | 0.98 |

Numbers round to nearest integer and have a minimum of 1. These are prototype
balancing values, **not** finalized multiplayer difficulty settings. The
four-hero test encounter still uses its original numbers without scaling.

## Prototype content and scope

The original Roboduck and 3-card starter set have been reused to verify a
complete navigable Act 1 loop. The boss, **Alextron Sentinel**, has dedicated
HP/damage values but intentionally reuses Roboduck artwork until approved
boss artwork exists. Combat rewards/shop/events are functional but deliberately
limited; unique enemies, relics, expanded cards, narrative events, and polished
difficulty are future milestones.

Act 2 and networked multiplayer are **not implemented**. Run resources persist
between encounters, but exiting the game does not save or resume a run.

## Test coverage

- `tests/simple_cards_test.gd` — existing combat rules and four-hero regressions
- `tests/combat_smoke_test.gd` — FIFO and basic targeting
- `tests/act1_run_test.gd` — seeded maps, 30-seed reachability and density
  checks, mandatory boss, passives, solo scaling, and safety frames for twelve
  menu/combat character-art resources
- `tests/visual_smoke_test.gd` — real Godot menu clicks, actual selected-hero
  combat, targeting, reward/shop/event/rest buttons, Act 1 completion, and
  multiplayer lobby placeholder

The two GitHub Actions workflows upload test results and rendered 1600×900
screenshots after every push. Visual snapshots are **not** approved baselines
until they have been explicitly reviewed.
