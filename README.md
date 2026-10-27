# APTITUDE: Rise of Alextron - v0.9.5 Native Main Menu Buttons

This is a GODOT GAME PROJECT, not a screenshot or standalone image.

## Change from v0.9.4

- Removed the invisible clickable rectangles that tried to track the painted menu buttons.
- Placed ONE opaque styled right-hand menu panel over the original printed buttons in the background artwork. No duplicate visible button artwork is left in the game; the rest of the approved splash art is unchanged.
- Added exactly FOUR native Godot Button controls, styled dark metal / gold, with decorative icons extracted from the approved main-menu art:
  * SINGLE PLAYER => opens four-hero battle.
  * MULTIPLAYER => opens the existing Coming Soon modal.
  * SETTINGS => opens existing music volume / mute / fullscreen modal.
  * QUIT => exits game.
- Mouse, keyboard focus, and visual hover outline all belong to the same Button Control. Click regions exactly match the visible button bounds.
- All controls are within the 1600 x 900 stage. Godot canvas_items stretch keeps input and visuals matched if window resolution changes.
- Existing looping music, cards, deck overlays, game rules, enemy HP, and four approved hero models are unchanged.

## Install and test

1. Extract ZIP into a NEW folder; in Godot 4.7 import project.godot.
2. Press F5 to reach menu and confirm no underlying second set of buttons is visible.
3. Hover all 4 visible buttons; the hover border should match the button itself.
4. Check Multiplayer, Settings, Single Player, and Quit. Music should keep playing across the first three.
5. Test at 1600 x 900 and fullscreen.

## Status

ZIP/package and placement were checked. Godot was not installed in the build environment, so final in-engine verification is required.
