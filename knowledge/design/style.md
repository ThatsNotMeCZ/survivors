# Style

Chunky **32px** pixel art, vessel taller than fodder (mite 24 / spitter 28). Square fallback sheets display at 40px; authored sheets keep native frame size (Homunculus 32×48). Silhouette over detail. Arena camera `viewZoom` in `world.json` (2.5) so that scale reads on 1080p.

HUD, pause, level-up, and menus are HTML in `src/ui/` using Dark Hermetic tokens (`theme.css`): brass, ember, mercury, parchment. Not Phaser text.
- **Main menu circle**: Authored sprite (`src/ui/cinder-circle.ts`) rendered via WebGL with a slow in-place occult breathing/blink (~6.5s wave, no external glow spill into surroundings).
- **The Hall (Lobby) background**: Fullscreen WebGL fragment shader (`src/ui/hall-backdrop.ts`) with dark cosmic violet depth, domain-warped aetheric smoke, light cone, perspective-squashed transmutation seal with rotating sigils under vessel feet, and rising embers (dimmed/cold when vessel is sealed).

Authored PNGs live in `public/sprites/` (`knowledge/tech/sprites.md`). Entity bodies are spritesheets keyed by catalog id — **not** by biome. Cinder, Rime, and Glacial share Homunculus / a mite until you add a new entity with its own sheet. Procedural canvases in `src/view/procedural-pixel-art.ts` fill any id that has no PNG. Do not draw high-res vectors in the entity update loop.

Arena floor is a cached 2560×2560 stamp of 4× 64px tiles per biome (hash `tileX * 73856093 ^ tileY * 19349663`), with ~12.5% rune accents. Env atlas in `public/sprites/env/`. Transmutation Circle uses the authored `{theme}-circle` plus a charge shader (`circle-charge-shader.ts`). Ambient ash/snow/mist cap 45; vignette is CSS; additive glow only on player / circle / primed urns.

## Elites

Elites spawn scaled up with one of two distinct affixes (no floor glyph; marked via dedicated shaders in `elite-affix-shader.ts`):

- **Shielder** (blue outline): Distinct 1px azure outline around the entity silhouette (`#4d9be6` / `#8fd3ff` active, `#484a77` broken). Carries a regenerating Aether Shield (+30% max HP ward, recharges after 5s unharmed).
- **Noxious** (green overlay): Caustic viridian shader overlay (`#1ebc73`, `#91db69`, `#239063`) with subtle animated pulse over the entire sprite. Inflicts contact slow and detonates into a 6s acid pool post-mortem.

## VFX do the wow

Hit spark, dash afterimage, death burst, ranged muzzle. Authored `public/sprites/fx/{id}.png` wins when present (projectiles face +X and rotate to velocity at native size). GPU `SpriteGPULayer` sparks stay the fallback (pooled, hide with alpha/scale 0). Windup telegraph is a Graphics line; skill zones may overlay an FX still or a dedicated shader (brimstone line, condemn tether, skill impact). Dash afterimages are faded player copies. Boss hazards and biome ambient are custom GLSL (`boss-shaders.ts`, `ambient-shader.ts`, `cinder-smoke-shader.ts`, `env-hazard-shader.ts`).

## Production path

1. Drop `public/sprites/entities/{id}.png` (horizontal frames). Optional `{id}.json` (compact anims or Pixelorama project JSON) names idle/walk/attack.
2. Drop `public/sprites/items/{id}.png` and `skills/{id}.png` at 24px.
3. Restart `bun run dev` (manifest watcher). Arena `flipX` for left.
4. Eyes / floor stay procedural until those folders have PNGs. Drop `fx/{id}.png` to replace sparks / bolts for that id.
