# Style

Chunky **32px** pixel art, vessel taller than fodder (mite 24 / spitter 28). Square fallback sheets display at 40px; authored sheets keep native frame size (Homunculus 32×48). Silhouette over detail. Arena camera `viewZoom` in `world.json` (2.2 on Godot) so that scale reads on 1080p.

HUD, pause, level-up, and menus are HTML in `web/src/ui/` using Dark Hermetic tokens (`theme.css`): brass, ember, mercury, parchment. Not Phaser text. Godot chrome uses the same tokens: **BillJilly** for display titles (≥18px, grayscale AA) and dark-chrome copy (`body_font`, grayscale AA, no drop shadow); **Source Sans 3 600** for parchment / dark-ink copy (`apply_ink_label` on Alchemist's Desk and Hall dossier; import hinting/subpixel, no runtime override). Floor **13px**. World renders in a 1920×1080 SubViewport (`WorldHost` nearest-fill). Overlay UI is a CanvasLayer sibling on the root window. Stretch is `canvas_items` / `expand` / `fractional` so font oversampling re-rasterizes glyphs at window size. Pixel snap is on the world SubViewport only. Display BillJilly keeps subpixel off. Archives **Bestiary / Reliquary** tiles are a fixed **112×148** inventory grid (64px art, 8px gap); window resize changes column count, not tile size. No yellow focus ring on buttons. Hover is mouse-only; gamepad will reuse hover when a pad is connected and in use.
- **Main menu circle**: Authored sprite (`web/src/ui/cinder-circle.ts`) rendered via WebGL with a slow in-place occult breathing/blink (~6.5s wave, no external glow spill into surroundings).
- **The Hall (Lobby) background**: Fullscreen WebGL fragment shader (`web/src/ui/hall-backdrop.ts`) with dark cosmic violet depth, domain-warped aetheric smoke, light cone, perspective-squashed transmutation seal with rotating sigils under vessel feet, and rising embers (dimmed/cold when vessel is sealed).

Authored PNGs live in `web/public/sprites/` (`knowledge/tech/sprites.md`). Entity bodies are spritesheets keyed by catalog id — **not** by biome. Cinder, Rime, and Glacial share Homunculus / a mite until you add a new entity with its own sheet. Procedural canvases in `web/src/view/procedural-pixel-art.ts` fill any id that has no PNG. Do not draw high-res vectors in the entity update loop.

Arena floor is a cached stamp of 4x 64px tiles per biome (hash `tileX * 73856093 ^ tileY * 19349663`), with ~12.5% rune accents (web: 2560x2560; Godot circular arena: 6000x6000 diameter via cached 1024x1024 `FloorStamp.build_chunks` tiles). Env atlas in `web/public/sprites/env/`. **Floor tiles are darkened per biome** (`prepareFloorTileStamp` on web, `FloorStamp._darken_floor_color` on Godot) so characters, pickups, and HUD read against the stone: Cinder damps lava veins and lifts dark grout; Rime/Glacial scale ice and slate down (~0.38-0.58). Borders/walls are not passed through that pass. On Godot, Alchemical Vents use `vent_erupt.gdshader` for glowing magma fissures on telegraph and an upward pixel-snapped eruption column on erupt (zero camera shake), while charging the Transmutation Circle drives arena-wide floor cracks via `circle_cracks.gdshader` and boss arrival uses `boss_emerge.gdshader`. Transmutation Circle uses the authored `{theme}-circle` plus a charge shader (`circle-charge-shader.ts`). Ambient ash/snow/mist cap 45; vignette is CSS; additive glow only on player / circle / primed urns.

Godot chrome avoids Unicode glyphs missing from `BillJilly.ttf` by mounting 24x24 `icon-*` sprites (`gui_agent.pxo`) via `UiAtlas.make_icon`, all 32 catalog skill icons (`skills/*.png`) exist on disk in Resurrect 64 + `#000000`, and every `btn-cta` plaque (`main_menu`, `hall`, `recap`) is sized at least 84px tall (`92px` for two-line Commence, `84px` for Run Again and demo Wishlist) over the 141x84 / 141x124 hover `btn-cta` 9-slice.

**Environment hazards** are Resurrect 64 palette pools, not hard sprite cutouts. Web feathers authored `{theme}-hazard-*` frames (`env-blended-*` in `pixel-textures.ts`) and overlays `env-hazard-shader.ts`. Godot draws the same frames and feathers in `env_hazard.gdshader` (radial alpha + Bayer rim so pixels melt into the floor stamp), then mixes a liquid-only flow / bubble overlay snapped to the same Resurrect 64 lava (`#2e1815` `#9e2835` `#ea4f36` `#f79617` `#f9c22b`) / acid (`#239063` `#1ebc73` `#91db69` `#cdff82`) / ice (`#1e3a5f` `#4d9be6` `#8fd3ff`) ramps. Hurtbox radius and sim collision stay unchanged.

**Arena pillars** use a feet origin: collision circle sits on the sprite base (`originY = (frameH - radius) / frameH`). Y-sort with the player so standing north of / behind a pillar is occluded by the shaft.

## Elites

Elites spawn scaled up with one of two distinct affixes (no floor glyph; marked via dedicated shaders in `elite-affix-shader.ts`):

- **Shielder** (blue outline): Distinct 1px azure outline around the entity silhouette (`#4d9be6` / `#8fd3ff` active, `#484a77` broken). Carries a regenerating Aether Shield (+30% max HP ward, recharges after 5s unharmed).
- **Noxious** (green overlay): Caustic viridian shader overlay (`#1ebc73`, `#91db69`, `#239063`) with subtle animated pulse over the entire sprite. Inflicts contact slow and detonates into a 6s acid pool post-mortem.

## VFX do the wow

Hit spark, dash afterimage, death burst, ranged muzzle. Authored `web/public/sprites/fx/{id}.png` wins when present (projectiles face +X and rotate to velocity at native size). GPU `SpriteGPULayer` sparks stay the fallback (pooled, hide with alpha/scale 0). Windup telegraph is a Graphics line; skill zones may overlay an FX still or a dedicated shader (brimstone line, condemn tether, skill impact). Dash afterimages are faded player copies. Boss hazards and biome ambient are custom GLSL (`boss-shaders.ts`, `ambient-shader.ts`, `cinder-smoke-shader.ts`, `env-hazard-shader.ts`).

## Production path

1. Drop `web/public/sprites/entities/{id}.png` (horizontal frames). Optional `{id}.json` (compact anims with per-clip `frameRate`) names idle/walk/attack.
2. Drop `web/public/sprites/items/{id}.png` and `skills/{id}.png` at 24px.
3. Restart `bun run dev` (manifest watcher). Arena `flipX` for left.
4. Eyes / floor stay procedural until those folders have PNGs. Drop `fx/{id}.png` to replace sparks / bolts for that id.
