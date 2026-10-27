# APTITUDE character/enemy trading-card asset standard

**Reusable template:** `res://scripts/trading_card.gd` creates a native
Godot Panel with the same name banner, art frame, category line, lore text,
and HP/attack (or Energy/rarity) footer for any hero, enemy or ability.
It is a source-driven **game UI** rather than a flattened Photoshop image.

## Canonical data and assets

| What | Canonical source | Source artwork |
|---|---|---|
| Hero combat stats, starting deck, game identity | `data/heroes.json` keyed by ID | `art/characters/<hero_id>/combat_sprite.png` |
| Hero biography, role, approved passive | `data/character_bios.json` keyed by ID | `art/characters/<hero_id>/bio_art.png` |
| Hero selection art | `data/character_bios.json` reference | `art/characters/<hero_id>/selection_portrait.png` |
| Non-boss enemy stats, move patterns, themes | `data/enemies.json` keyed by ID | `art/enemies/<enemy_id>.svg` |
| Hero attack/skill/power definitions | `data/cards.json` keyed by ID | `art/cards/<card_id>.svg` |
| Enemy group, scene, spawn list | `data/encounters.json` keyed by ID | `art/backgrounds/<group>.svg` |
| Encounter sampling configuration | `data/encounter_pools.json` | n/a |

## Stable IDs and file naming

Use lowercase `snake_case` IDs. Hero abilities have IDs beginning with
their hero's ID, e.g. `bryan_arc_flash` or `cristian_hb_guardrail`.
Enemy artwork always matches the enemy ID (e.g.
`teslabot_scout.svg`). Never copy asset artwork into button textures:
the UI loads artwork and draws its own interactive frames separately.

Each ability has:
`id`, `hero`, `name`, `type` (`attack|skill|power`),
`cost`, `target` (`enemy|self|ally|all_allies`), `effects`
(each `op` + `value`, with optional `hits`/`target`), `rarity`,
`description`, `art_key`. Keep numerical data authoritative in JSON,
not in artwork or tooltip-only strings.

Each enemy has:
`id`, `name`, `hp`, `damage`, `enemy_type`, `intent`,
`target`, `sprite`, `theme`, `description`, `moves`.
A move includes `kind`, optional `power`, `hits`, `block`,
`strength`, `status`, `team`. The core engine computes next intent.

Each encounter has:
`id`, `name`, `act`, `background`, `enemies`.
Use a new background for a themed machine family rather than duplicating
scene files for each spawn variant.

## Preserving existing approved artwork

`scripts/character_art.gd` adds transparent safe margins to existing
approved hero images at runtime; it doesn't rewrite original pixels.
All names and biographies are kept separate from source art. New scene
art is original editable SVG, imported by Godot like other textures.

**Boss assets and mechanics are reserved for a later joint design session.**

To add a new enemy, create one entry in `data/enemies.json`, one
matching `art/enemies/<id>.svg`, add it to a themed encounter and run
`tests/content_expansion_test.gd`. It will automatically appear in the
CharacterDex Enemies tab without needing a new screen or card template.
