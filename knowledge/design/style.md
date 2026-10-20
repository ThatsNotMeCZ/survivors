# Style

Chunky **32px** pixel art. Silhouette over detail. Arena camera `viewZoom` in `world.json` (2.5) so 32px reads on 1080p.

## Elites

Same mesh as the base enemy. Recolor + 1 glyph:

- red = burn
- blue = chain lightning
- green = poison slow

## VFX do the wow

Hit spark, dash afterimage, death burst, ranged muzzle. GPU `SpriteGPULayer` sparks (pooled, hide with alpha/scale 0). Windup telegraph is a Graphics line, not a sprite. Dash afterimages are faded player copies.

## Production path

1. One hand-drawn hero + 3 enemy silhouettes (64×64, white bg).
2. Optional Comfy img2img / pixel LoRA for extra poses.
3. Aseprite: shared palette (8–16 colors), shared pivot.
4. Code hue-shift for fodder variants.

Do not generate cinematic HD characters. They fail at 32px.
