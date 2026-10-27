# APTITUDE graphical QA (Godot 4.7.2)

This system adds **rendered screenshots and real GUI event smoke testing** without
changing gameplay rules or art. It supplements (does not replace) the existing
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

1. `01_main_menu.png` — title screen, Play / Settings / Quit
2. `02_main_settings.png` — settings opened from the title screen
3. `03_play_modes.png` — Single Player / Multiplayer, no Custom mode
4. `04_character_selection.png` — four approved hero models
5. `05_bio_bryan.png` — Bryan biography and passive
6. `05_bio_carlos.png` — Carlos biography and passive
7. `05_bio_manny.png` — Manny biography and passive
8. `05_bio_cristian_hb.png` — Cristian & HB biography and passive
9. `06_act1_map.png` — Single Player destination placeholder
10. `07_multiplayer_lobby.png` — Multiplayer destination placeholder
11. `08_combat_preview.png` — original four-hero sandbox preserved
12. `09_deck_inventory.png` — Deck overlay
13. `10_combat_settings.png` — Settings during combat
14. `11_drag_targeting.png` — mouse-dragged Attack over Roboduck
15. `12_after_card_play.png` — attack damages Roboduck
16. `13_victory.png` — victory state

Test-only fixtures ensure the Attack is in the hand and end the encounter;
they modify **only the in-memory test process**, not the game project or
approved assets. Interaction or rendering assertions cause the job to fail.
Logs and any available screenshots are uploaded **even on failure**.

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
