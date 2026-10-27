# APTITUDE graphical QA (Godot 4.7.2)

This system provides **rendered screenshots and real GUI event smoke testing** for
Milestone 2, including the gameplay-state changes. It supplements (does not replace) the existing
`APTITUDE Windows Godot Tests` workflow.

## Two independent checks

- **Windows Godot Tests**: Windows hosted runner, Godot 4.7.2, imports project,
  runs gameplay engine tests, and checks short headless startup.
- **APTITUDE Graphical QA**: Linux hosted runner with Xvfb (virtual 1600x900
  desktop) and Mesa software OpenGL. Runs Godot 4.7.2 in Compatibility mode.
  Captures *real rendered game frames* with the same game UI and assets.

Why a Linux virtual desktop? Standard hosted Windows workers do not reliably
expose an interactive GPU desktop to automated screen capture. This gives us a
reproducible software-rendered view immediately, while Windows-specific
headless tests remain independent. Visual differences between operating
systems/fonts are possible. A future optional Windows graphical runner can be
added when a stable desktop runner is available.

## Scripted journey

`tests/visual_smoke_test.gd` instantiates the actual `scenes/main.tscn`,
sends real mouse events to native Godot controls (not fake button callbacks),
and saves images in `test-results/screenshots/`:

1. `01_main_menu.png` — initial title screen
2. `02_main_settings.png` — title-screen settings
3. `03_play_modes.png` — Single Player / Multiplayer mode choices
4. `04_character_selection.png` — all four approved characters
5. `05_bio_bryan.png` — Bryan's biography and passive
6. `05_bio_carlos.png` — Carlos's biography and passive
7. `05_bio_manny.png` — Manny's biography and passive
8. `05_bio_cristian_hb.png` — Cristian & HB's biography and passive
9. `06_act1_branching_map.png` — three available starting paths
10. `06_boss_map_top.png` — map scrolled up toward the boss
10. `07_solo_combat.png` — single hero with scaled enemy
11. `08_deck_inventory.png` — current hero deck
12. `09_combat_settings.png` — combat settings overlay
13. `10_drag_targeting.png` — simulated card drag
14. `11_after_card_play.png` — verified card damage
15. `12_victory_reward.png` — choose a reward
16. `13_map_after_reward.png` — deck and coin persistence
17. `13_yellow_route_marker.png` — two visited nodes and the yellow marked connection
17. `14_event.png` — event choices
18. `14_shop.png` — shop choices
19. `14_rest.png` — rest choices
20. `14_boss_unlocked.png` — boss-only final route
21. `15_boss_combat.png` — boss encounter
22. `16_act1_complete.png` — Act 1 complete
23. `17_multiplayer_lobby.png` — multiplayer placeholder
24. `18_sprite_carlos.png` — Carlos's approved combat sprite, safely framed
25. `18_sprite_manny.png` — Manny's approved combat sprite, safely framed
26. `18_sprite_cristian_hb.png` — Cristian & HB's approved scissor lift in combat

Test-only fixtures force a known Attack, accelerated encounter wins and a boss-map jump;
they modify **only the in-memory test process**, not the game project or
approved assets. Full 15-floor route legality is verified separately in
`tests/act1_run_test.gd`. Interaction or rendering assertions cause the job to fail.
Logs and any available screenshots are uploaded **even on failure**.

27. `19_yard_wallpaper.png` — new scrapyard background and Arc Welder
28. `20_teslabot_factory_wallpaper.png` — Tesla factory with two Scouts

The Main Menu CharacterDex also includes:
- `02_character_dex_heroes.png`
- `02_character_dex_enemies.png`
- `02_character_dex_abilities.png`

## Review screenshots

Go to GitHub → Actions → **APTITUDE Graphical QA** → latest run →
**Artifacts** → `aptitude-graphical-qa`. Extract the archive and look in
`screenshots/`. The workflow also uploads `visual_smoke.log` and the
comparison report.

## Optional visual regression baselines

No screenshot is automatically treated as a "good" reference. Until
**you review and approve images**, comparison reports
`awaiting_approval` and does not fail just because there is no baseline.

After you approve a captured image, commit that exact PNG under
`tests/visual_baselines/` with the **same file name**. Subsequent runs compare
against that reference with `tests/compare_visuals.py`.

Comparison uses a per-pixel RGB tolerance (ignoring differences smaller than
40/255 in all channels) and fails if more than 3% of pixels exceed that
threshold. Changed screenshots are written to `test-results/diffs/`.
The threshold is intentionally adjustable if the environment changes.

**Never auto-update baselines as part of testing.** Review unexpected diffs
and intentionally approve updates only when the new visuals are correct.

## Run locally on Linux

Requires Xvfb, Mesa software OpenGL, Godot 4.7.2, Python 3, and Pillow.

```bash
godot --headless --path . --editor --import --quit
mkdir -p test-results/screenshots test-results/diffs
LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
  xvfb-run -a -s "-screen 0 1600x900x24" \
  godot --path . --resolution 1600x900 --rendering-method gl_compatibility \
  --script res://tests/visual_smoke_test.gd

python tests/compare_visuals.py \
  --screenshots test-results/screenshots \
  --baselines tests/visual_baselines \
  --diffs test-results/diffs \
  --report test-results/visual_comparison.json
```

## Known limitations

Screenshots and synthetic input validate specific routes through the GUI.
This is **not** an agent that freely plays the game or a replacement for human
testing on a Windows display. Mouse interactions and visual states are covered;
timing/audio impressions and all possible combat strategies are not.
