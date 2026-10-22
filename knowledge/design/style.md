# Style

Chunky **32px** pixel art, vessel body **40px** so it reads larger than fodder (mite 24 / spitter 28). Silhouette over detail. Arena camera `viewZoom` in `world.json` (2.5) so that scale reads on 1080p.

HUD, pause, level-up, and menus are HTML in `src/ui/` using Dark Hermetic tokens (`theme.css`): brass, ember, mercury, parchment. Not Phaser text.

Authored PNGs live in `public/sprites/` (`knowledge/tech/sprites.md`). Entity bodies are spritesheets keyed by catalog id — **not** by biome. Cinder and Rime share Homunculus / a mite until you add a new entity with its own sheet. Procedural canvases in `src/view/procedural-pixel-art.ts` fill any id that has no PNG. Do not draw high-res vectors in the entity update loop.

Arena floor is still a cached 2560×2560 stamp of 4× 64px tiles per biome (hash `tileX * 73856093 ^ tileY * 19349663`). Later stages swap that for authored **env blocks** in `public/sprites/env/`. Transmutation Circle is two pixelated rings + hexagram; charge fills the outer arc. Ambient ash/snow cap 45; vignette is CSS; additive glow only on player / circle / primed urns.

## Elites

Same mesh as the base enemy until a sheet exists for that elite id. Recolor + 1 glyph:

- red = burn
- blue = chain lightning
- green = **Noxious** poison slow (live: every elite, green glyph, acid corpse)

## VFX do the wow

Hit spark, dash afterimage, death burst, ranged muzzle. GPU `SpriteGPULayer` sparks (pooled, hide with alpha/scale 0). Windup telegraph is a Graphics line, not a sprite. Dash afterimages are faded player copies.

## Production path

1. Drop `public/sprites/entities/{id}.png` (horizontal frames). Optional `{id}.json` names idle/walk.
2. Drop `public/sprites/items/{id}.png` and `skills/{id}.png` at 24px.
3. Restart `bun run dev` (manifest watcher). Arena `flipX` for left.
4. Eyes / VFX / floor stay procedural until those folders have PNGs.
