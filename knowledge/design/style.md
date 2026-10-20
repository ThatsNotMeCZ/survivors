# Style

Chunky **32px** pixel art. Silhouette over detail. Arena camera `viewZoom` in `world.json` (2.5) so 32px reads on 1080p.

HUD, pause, level-up, and menus are HTML in `src/ui/` using Dark Hermetic tokens (`theme.css`): brass, ember, mercury, parchment. Not Phaser text.

Procedural canvases live in `src/view/procedural-pixel-art.ts` (`SpriteCache` by entity+biome+frame, player by vessel+biome). Offscreen integer draw → 4-neighbor outline (`#120a0d` Cinder / `#08101a` Rime) → Phaser canvas textures. Homunculus and The Penitent are distinct meshes (clay runner vs hooded robe). Hall portraits reuse that mesh with interior holes sealed so the transmutation-circle grid does not show through. Swap a key for a ComfyUI PNG later without changing render code. Do not draw high-res vectors in the entity update loop.

Arena floor is a cached 2560×2560 stamp of 4× 64px tiles per biome (hash `tileX * 73856093 ^ tileY * 19349663`). Transmutation Circle is two pixelated rings + hexagram; charge fills the outer arc. Ambient ash/snow cap 45; vignette is CSS; additive glow only on player / circle / primed urns.

## Elites

Same mesh as the base enemy. Recolor + 1 glyph:

- red = burn
- blue = chain lightning
- green = **Noxious** poison slow (live: every elite, green glyph, acid corpse)

## VFX do the wow

Hit spark, dash afterimage, death burst, ranged muzzle. GPU `SpriteGPULayer` sparks (pooled, hide with alpha/scale 0). Windup telegraph is a Graphics line, not a sprite. Dash afterimages are faded player copies.

## Production path

1. One hand-drawn hero + 3 enemy silhouettes (64×64, white bg).
2. Optional Comfy img2img / pixel LoRA for extra poses.
3. Aseprite: shared palette (8–16 colors), shared pivot.
4. Code hue-shift for fodder variants.

Do not generate cinematic HD characters. They fail at 32px.
