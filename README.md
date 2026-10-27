# APTITUDE: Rise of Alextron — v0.11.0 (Hero Cards, Bestiary & CharacterDex)

**Godot 4.7.2** native Windows game prototype, built around four approved
characters and deckbuilding combat inspired by the turn-based roguelike genre.

## NEW: Four unique deckbuilding identities

Version **v0.11.0** adds **30 original character-specific cards** (six each
for Bryan, Carlos, Manny, Cristian and HB: 3 Attacks, 2 Skills, 1 Power
per person). Cristian and HB remain **one shared playable unit**, with
12 available signature abilities, designed for the existing 3-energy
turn rhythm. Each card has data-driven cost/effects/rarity and its own
editable SVG illustration in `art/cards/`.

- **Bryan**: conductor attacks, Weak, Vulnerable, protecting and drawing.
- **Carlos**: multi-hit nailgun offense, cheap moves, persistent Strength.
- **Manny**: tactical debuffs, team Block, deck velocity and lasting Plating.
- **Cristian & HB**: lift-based heavy attacks, guardrails and defensive powers,
  plus six HB-signature attacks, harness skills and a draw-focused Power Bank.

Winning combats now offers three weighted, distinct **hero-specific card
rewards**. You may choose one or repair +8 HP. Those cards persist in the
run's deck and are fully playable in later fights.

## NEW: CharacterDex

Open **Main Menu → CharacterDex** to browse **Heroes**, **Enemies**, or
**Ability Cards**. Character and machine entries share one native Godot
trading-card template with artwork, descriptions and stats:
`scripts/trading_card.gd`. Every hero's approved combat model and biography
are reused, while each new machine and ability has a unique original SVG
asset.

The roster now includes **eight new non-boss machines** in addition to
Roboduck: Tesla Scout, Tesla Brute, Capacitor Bot, Rivet Drone, Arc Welder,
Scaffold Spider, Cement Mixer MK-II and Foreman Droid. Their attacks,
defensive actions, charge cycles and statuses are telegraphed.

Fights now select from new themed encounter groups. Scrapyard machines use
`art/backgrounds/yard_dusk.svg`; Teslabot crews use
`art/backgrounds/teslabot_factory.svg`. Their wallpapers and sprite
artwork are stored separately from enemy stats and moves.

**The Act 1 boss is deliberately unchanged**; its art and mechanics are
reserved for collaborative design.

See `docs/CONTENT_EXPANSION.md` and `docs/CARD_ASSET_STANDARD.md`
for balance assumptions, stats, directory standards and implementation
details.

## Play flow

Main Menu → Play → Single Player → choose one hero → Character Bio → Confirm →
**Act 1: The Construction Zone**.

- **15 encounter floors** with three starting choices and **2–5 randomly
  placed nodes on later floors**, connected by reproducible seeded routes.
  Only one node is visited per floor.
- Three paths are available from the first floor; players choose one reachable
  node per floor with **no backtracking** and no floor skipping.
- **Scrollable map**: start near the bottom and scroll toward the boss. Thin
  white chalk lines and six chalk-style icons (normal combat = crossed swords).
  Only the **chosen route** receives a broad yellow highlighter effect.
- The map shares **the exact header construction** (logo, coins, potion slots,
  Deck and Settings controls) with the existing combat screen.
- **Mandatory floor-16 boss**: Alextron's Sentinel. Defeat it to finish Act 1;
  Act 2 is marked *Coming Soon*.
- Nodes include combat, elite combat, event, shop and rest.
- Victory opens a reward screen; the selected reward then returns you to the
  map. Event/shop/rest screens provide working choices.
- Single Player deploys **only the chosen hero and their deck**.
- HP, max HP, coins and reward-modified deck persist across encounters.
- Encounter HP/damage scaling is opt-in based on 1–4 party members; currently
  used by the **one-player Act 1** mode.

Multiplayer follows the same hero selection and character bio screens, then
opens the previously agreed **lobby placeholder**. It is not networked yet.
There is no Custom mode.

## Heroes and implemented passives

| Hero | Passive (applies at the beginning of each Act 1 encounter) |
|---|---|
| Bryan | Conduit Discipline: +1 starting Block |
| Carlos | Nail Gunner: +1 damage on first accepted Attack each combat |
| Manny | Toolbox Talk: draw 6 cards instead of 5 on combat start |
| Cristian & HB | Elevated Position: +2 starting Block |

All four start with 60 HP in the prototype. Character biographies and art are
separate, reusable resources in `data/character_bios.json` and
`art/characters/<hero>/`. Approved original assets in `art/heroes/` have
**not been altered**. A shared, cached framing layer adds a transparent
safety margin to combat sprites, selection portraits and bio art. This avoids
UI-edge clipping without distorting the approved images. Artwork pixels already
missing at a source image's edge cannot be recreated by framing alone.

## First-pass Act 1 encounter economy

- Combat and elite combat use the existing Roboduck encounter templates;
  solo encounters scale enemy health/damage down.
- A combat win awards **25 coins** and one choice: add Attack, add Block, or
  restore 8 HP.
- Event: take 20 coins or repair 8 HP.
- Shop: restore 15 HP for 20 coins, increase max HP by 5 for 30 coins, or leave.
- Rest: restore 12 HP or gain 5 maximum HP (and heal 5).
- Boss: one Alextron Sentinel prototype enemy using *temporary Roboduck artwork*
  until the distinct boss art and mechanics are designed.

**Prototype limitations:** The enemy roster, three starter card types, rewards,
shop/events, and boss mechanics are intentionally simple placeholders for more
varied Act 1 content. There is no Act 2, multiplayer networking, persistent
save-and-resume, or relic system yet. Runs persist **between encounters only**;
exiting the run does not save it. Balancing is preliminary.

## Development and testing

Open `project.godot` in Godot 4.7.2 and press F5.

GitHub Actions runs two independent suites on every commit:

1. **APTITUDE Windows Godot Tests**: Windows asset import, battle tests, Act 1
   seed/map/passive tests across **30 generated maps**, transparent asset
   margins for all four characters, and startup checks.
2. **APTITUDE Graphical QA**: Godot 4.7.2 rendered at 1600×900 under a Linux
   virtual desktop. It navigates CharacterDex, drags a card in combat, goes
   through the scrollable map/reward/shop/rest/event screens, inspects each hero
   in combat, checks the yellow selected route, and verifies boss completion.

Open GitHub → **Actions** → latest **APTITUDE Graphical QA** → Artifacts →
`aptitude-graphical-qa` to download original-size screenshots and logs.

Technical docs: `docs/ACT1_MILESTONE2.md` and `docs/GRAPHICAL_QA.md`.
