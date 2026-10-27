# APTITUDE: Rise of Alextron — v0.10.0 (Milestone 2)

**Godot 4.7.2** native Windows game prototype, built around four approved
characters and deckbuilding combat inspired by the turn-based roguelike genre.

## Play flow

Main Menu → Play → Single Player → choose one hero → Character Bio → Confirm →
**Act 1: The Construction Zone**.

- **15 encounter floors** with three visible nodes on each floor and connected
  paths generated from a displayed random seed.
- Three paths are available from the first floor; players choose one reachable
  node per floor with **no backtracking**.
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
**not been altered**.

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
   seed/map/passive tests, and startup checks.
2. **APTITUDE Graphical QA**: Godot 4.7.2 rendered at 1600×900 under a Linux
   virtual desktop. It clicks real Godot buttons, drags a card in combat, goes
   through the map/reward/shop/rest/event screens, and checks boss completion.

Open GitHub → **Actions** → latest **APTITUDE Graphical QA** → Artifacts →
`aptitude-graphical-qa` to download original-size screenshots and logs.

Technical docs: `docs/ACT1_MILESTONE2.md` and `docs/GRAPHICAL_QA.md`.
