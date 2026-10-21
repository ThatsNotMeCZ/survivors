# Style

Chunky **32px** pixel art, vessel body **40px** so it reads larger than fodder (mite 24 / spitter 28). Silhouette over detail. Arena camera `viewZoom` in `world.json` (2.5) so that scale reads on 1080p.

HUD, pause, level-up, and menus are HTML in `src/ui/` using Dark Hermetic tokens (`theme.css`): brass, ember, mercury, parchment. Not Phaser text.

Procedural canvases live in `src/view/procedural-pixel-art.ts` (`SpriteCache` by entity+biome+frame, player by vessel+biome). Offscreen integer draw → 4-neighbor outline (`#120a0d` Cinder / `#08101a` Rime) → Phaser canvas textures. Homunculus and The Penitent are distinct meshes (muscular clay brute vs hooded robe). Hall portraits reuse that mesh with interior holes sealed so the transmutation-circle grid does not show through. A ComfyUI PNG in `public/sprites/{key}.png` (see `knowledge/tech/comfy.md`) replaces that key without changing render code. Do not draw high-res vectors in the entity update loop.

Arena floor is a cached 2560×2560 stamp of 4× 64px tiles per biome (hash `tileX * 73856093 ^ tileY * 19349663`). Transmutation Circle is two pixelated rings + hexagram; charge fills the outer arc. Ambient ash/snow cap 45; vignette is CSS; additive glow only on player / circle / primed urns.

## Elites

Same mesh as the base enemy. Recolor + 1 glyph:

- red = burn
- blue = chain lightning
- green = **Noxious** poison slow (live: every elite, green glyph, acid corpse)

## VFX do the wow

Hit spark, dash afterimage, death burst, ranged muzzle. GPU `SpriteGPULayer` sparks (pooled, hide with alpha/scale 0). Windup telegraph is a Graphics line, not a sprite. Dash afterimages are faded player copies.

## Production path

1. `bun run art:comfy` then `bun run art:ref -- runner` — one Homunculus **front** identity at 1024px into `public/sprites/_ref/` (native txt2img).
2. Item icons: `bun run art:item-ref -- glass-cannon` writes a 1024px ref to `public/sprites/_ref/items/{id}.png`. `bun run art:item -- glass-cannon` does that plus downsample to `public/sprites/px-item-{id}.png` at 24px. Skill icons are the same 2-step: `bun run art:skill -- bolt` → `_ref/skills/{id}.png` then `px-skill-{id}.png` at 24px. Prompts name a concrete object (`knowledge/tech/comfy.md`); `_in/items-sheet.jpeg` is the visual target for items. Portraits ride `art:generate`.
3. Homunculus idle is the side stand (`art:slice` from `_in/runner_idle.jpeg`); flipX for left. Walk frames slice from `_in/runner_walk.jpeg` (or `bun run art:walk -- runner` via ControlNet). The Penitent still uses front idle.
4. Code hue-shift for fodder variants. Eyes / VFX / floor stay procedural.

Game sprites stay catalog size (player 40, icons 24). High-detail character art lives in `_ref/`; item refs in `_ref/items/`; skill refs in `_ref/skills/`.
