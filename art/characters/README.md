# Reusable approved character artwork

These folders deliberately keep character artwork separate from user interface,
menu backgrounds, biographies, and combat rules.

Each of the four hero IDs (`bryan`, `carlos`, `manny`, `cristian_hb`) has:

- `approved_reference.png` — approved character reference sheet/art
- `selection_portrait.png` — character-select card artwork
- `bio_art.png` — full hero art for the bio screen
- `combat_sprite.png` — approved transparent battlefield model

Initially the last three paths reuse the same approved transparent battlefield
art, which guarantees consistency across screens. Once an art variant is
explicitly approved, update only the appropriate role asset. The original
source art in `art/heroes/` is preserved.

Character names, biography text, combat roles, and proposed passive details
are maintained in `data/character_bios.json`; no text is painted into the
artwork. GUI buttons are native Godot controls.

## Shared safe-canvas framing (v0.10.1)

`scripts/character_art.gd` non-destructively pads the approved transparent
images with a 6.25% clear border, caches the textures, and applies them across
combat, selection and bios. Source PNG bytes are never rewritten; model heights
and the shared ground baseline are calculated from the actual content bounds.

This prevents interface clipping caused by portraits fitting too tightly. If
an element was *already absent* beyond a source image's edge, a new explicitly
approved outpainted original would still be necessary to recreate it.
