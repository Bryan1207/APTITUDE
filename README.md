# APTITUDE: Rise of Alextron — v0.9.6 Menu Flow

Godot 4.7.2 Windows cooperative deckbuilder prototype. The current milestone
implements **the navigable menu and character-selection experience**, while
preserving the previous playable four-hero combat prototype.

## Navigation

```
MAIN MENU
├── PLAY
│   ├── SINGLE PLAYER
│   │   └── CHARACTER SELECT (Bryan, Carlos, Manny, Cristian & HB)
│   │       └── CHARACTER BIO (Back / Confirm only)
│   │           └── ACT 1 — THE CONSTRUCTION ZONE (placeholder)
│   │               └── COMBAT PREVIEW (previous four-hero prototype)
│   └── MULTIPLAYER
│       └── CHARACTER SELECT
│           └── CHARACTER BIO (Back / Confirm only)
│               └── MULTIPLAYER LOBBY (placeholder, no networking yet)
├── SETTINGS (music, mute, fullscreen)
└── QUIT
```

**No Custom mode.** Single Player, Multiplayer and the character bio routes
use actual Godot buttons, not baked-in image click areas.
Character selection requires a hero before Continue is enabled.
Back returns to the previous screen and preserves the hero selection where useful.

## Approved character writing

All four biographies, roles and passive descriptions are in
`data/character_bios.json`. Starting HP is currently 60 for each character.

| Hero | Combat role | Approved passive |
| --- | --- | --- |
| Bryan — The Conduit Bender | Balanced / Control | Conduit Discipline: Start combat with 1 Block |
| Carlos — The Rooftop Outlaw | Aggressive / Damage | Nail Gunner: First Attack each combat deals +1 damage |
| Manny — The Superintendent | Support / Strategy | Toolbox Talk: Draw 1 additional card at combat start |
| Cristian & HB — The Lift Operators | Defense / Teamwork | Elevated Position: Start combat with 2 Block |

**Milestone boundary:** Passives are displayed but *not yet activated* in the
combat engine. The Act 1 branching map currently displays a preview layout,
not fully generated encounter navigation. Selected-hero-only combat, passives,
branching map/encounters, and multiplayer networking are future gameplay work.
The **COMBAT PREVIEW** button deliberately opens the former four-hero sandbox
so existing combat controls and regression tests remain accessible.

## Artwork source and reuse

`art/characters/<hero>/` stores:
- `approved_reference.png`: approved character appearance (Bryan and Carlos v2)
- `selection_portrait.png`: matching transparent hero art for selection
- `bio_art.png`: matching transparent full hero art for biography
- `combat_sprite.png`: approved combat art

At this milestone the three transparent poses start from the existing approved
battlefield sprite, so appearances remain consistent. Originals under
`art/heroes/` are unchanged; background scenery and interactive GUI controls
are kept separate from the character images.

## Testing and reviewing builds

The repository has two GitHub Actions workflows:

- **APTITUDE Windows Godot Tests**: headless Windows import/startup and engine tests
- **APTITUDE Graphical QA**: 1600×900 virtual display, synthetic menu/input
  navigation, and 16 screenshots, including every character bio and combat

Open Actions → the latest Graphical QA run → Artifacts → `aptitude-graphical-qa`.
For screenshots/baseline policy see `docs/GRAPHICAL_QA.md`.

Open `project.godot` in Godot 4.7.2 and press F5 to run locally.
