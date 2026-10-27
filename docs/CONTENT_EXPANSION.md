# APTITUDE content expansion — v0.11.0

The newest original cards and enemies are balanced against **APTITUDE's**
existing 1-damage Attack, 1-Block Skill, 3 energy/turn, and 60 starting HP.
Those are intentionally *not* copied from Slay the Spire's numerical card
values. All costs are 0–2 for this first pass.

## Research basis and design philosophy

- Slay the Spire teaches combat as spending **three energy** on a limited
  draw, with player decisions against **telegraphed enemy actions**.
- It provides meaningfully weak starter decks and offers cards through
  combat rewards; the deckbuilding choice shapes subsequent fights.
- Mega Crit's developers have discussed using pick rates, win rates and
  damage statistics to refine card design over long playtest cycles.

Our first pass instead focuses on a small, understandable interaction set:
damage, Block, draw, Strength, Weak, Vulnerable, Plating and Focus. Distinct
characters should have different strengths without requiring twenty novel
mechanics at once.

Sources:
- https://slaythespire.wiki.gg/wiki/Key
- https://slaythespire.wiki.gg/wiki/Card_Rewards
- https://www.gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder

## All 24 unique hero cards

### Bryan

| Card | Type | Energy | Text |
|---|---|---:|---|
| Conduit Jab | attack | 1 | Deal 3 damage with a precise conduit strike. |
| Live Wire | attack | 1 | Deal 2 damage. Apply 2 Weak. |
| Arc Flash | attack | 2 | Deal 5 damage. Apply 1 Vulnerable. |
| Lockout / Tagout | skill | 1 | Gain 4 Block. Draw 1 card. |
| Busbar Guard | skill | 2 | Gain 6 Block. Draw 2 cards. |
| Closed Circuit | power | 2 | Gain 1 Strength and 1 Plating (Block each new round). |

### Carlos

| Card | Type | Energy | Text |
|---|---|---:|---|
| Nail Burst | attack | 1 | Deal 2 damage twice. |
| Roofbreaker | attack | 2 | Deal 7 damage. |
| Ridge Run | attack | 0 | Deal 2 damage. Costs 0 Energy. |
| Hard Hat | skill | 1 | Gain 4 Block. Draw 1 card. |
| Quick Reload | skill | 0 | Draw 2 cards. Exhaust. |
| Full Send | power | 2 | Gain 2 Strength for this combat. |

### Manny

| Card | Type | Energy | Text |
|---|---|---:|---|
| Punch List | attack | 1 | Deal 2 damage. Apply 2 Weak. |
| Change Order | attack | 2 | Deal 4 damage. Draw 1 card. |
| Redline | attack | 1 | Deal 1 damage. Apply 2 Vulnerable. |
| Safety Meeting | skill | 1 | Give yourself or an ally 4 Block. |
| Crew Brief | skill | 1 | All living heroes gain 3 Block. |
| Site Plan | power | 2 | Gain 1 Plating and draw +1 each new round. |

### Cristian & HB

| Card | Type | Energy | Text |
|---|---|---:|---|
| Lift Ram | attack | 1 | Deal 4 damage from the platform. |
| Spotter Shot | attack | 1 | Deal 2 damage. Apply 1 Weak. |
| Overhead Drop | attack | 2 | Deal 7 damage. |
| Guardrail | skill | 1 | Gain 5 Block. |
| Double Check | skill | 0 | Gain 2 Block. Draw 1 card. |
| High Ground | power | 2 | Gain 2 Plating and 1 Strength. |

## Eight new machine types

| Enemy | Base HP | Base attack | Theme | Repeating intent cycle |
|---|---:|---:|---|---|
| Tesla Scout | 16 | 5 | teslabot | attack → charge → attack |
| Tesla Brute | 26 | 7 | teslabot | attack → guard → attack |
| Capacitor Bot | 19 | 4 | teslabot | charge → attack → guard |
| Rivet Drone | 14 | 4 | yard | attack → attack |
| Arc Welder | 21 | 5 | yard | attack_vulnerable → guard → attack |
| Scaffold Spider | 18 | 5 | yard | guard → attack → attack |
| Cement Mixer MK-II | 28 | 6 | yard | attack → charge → attack |
| Foreman Droid | 25 | 5 | teslabot | charge → attack_weak → guard |

Boss is intentionally excluded: **Alextron Sentinel remains unchanged**
until the user and designer approve its actual design together.

## Combat status rules

- **Weak**: reduces outgoing direct attack damage to 75% for one turn per
  stack of duration (rounded, minimum one for a machine attack).
- **Vulnerable**: increases incoming direct damage to 150% for the indicated
  duration.
- **Plating**: permanent Block at the beginning of every new player round
  during that encounter.
- **Focus**: +1 starting card per round per stack, not an increase in
  maximum hand size.
- **Multi-hit**: applies separate blows; normal Strength applies to
  each hit, while Carlos's approved first-Attack +1 bonus applies to the
  FIRST hit only.
- **Power**: plays once per encounter and exhausts. Quick Reload also
  exhausts after resolving.
- **Target overrides**: an Attack can hit an enemy then draw for its caster
  without applying draw to the machine.
- **Enemy patterns**: next action is presented above each living enemy, including
  the number of Weak or Vulnerable stacks it will apply.
  Old Roboduck and prototype boss retain their original fixed attack behavior.
- **Enemy-applied debuffs**: Weak and Vulnerable newly inflicted during an enemy
  phase survive into the next player turn. Only stacks present before that enemy
  phase tick at its end. Arc Welder applies **2 Vulnerable** so its guard turn
  does not waste the debuff before its follow-up strike.

This remains an early balance pass: enemy HP/damage is scaled by the existing
solo difficulty toggle and no player win-rate dataset exists yet.

## Encounter families and backgrounds

Normal encounters rotate between the original Roboduck, scrap-yard welding,
rivet, scaffolding and mixer crews, and teslabot factory squads. Elite
encounters use heavier scrap-yard or Tesla security groups.

New SVG battle wallpapers are:
- `res://art/backgrounds/yard_dusk.svg`
- `res://art/backgrounds/teslabot_factory.svg`

The FIRST Act 1 combat remains Roboduck for a familiar introduction.
Later choices depend on run seed, floor and chosen map lane. Boss routing
remains exactly the existing mandatory floor-16 encounter.

## Rewards and tests

Winning a non-boss combat presents three **distinct** hero-only cards.
Initial selection uses common/uncommon/rare weights of 6:3:1, sampled
without replacement. Repairing +8 HP remains an alternative. No enemy or
other hero's card can enter the selected character's reward pool.

`tests/content_expansion_test.gd` verifies all 24 cards can execute, the
new SVGs load, the bestiary/encounters are internally consistent, and
unique-card rewards persist. Graphical QA navigates CharacterDex,
renders rewards and checks both themed wallpapers.

We should balance with real playtesting next: average HP lost by encounter,
how often rewards are picked, run completion rates, per-hero win rates,
and card pick frequency. Until then, balance values remain provisional.
