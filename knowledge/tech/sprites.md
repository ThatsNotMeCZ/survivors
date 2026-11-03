# Sprites

Drop finished art into `public/sprites/`. Vite rewrites `manifest.json` on `dev` / `build` by scanning folders. Missing entity sheets fall back to procedural canvases in `src/view/procedural-pixel-art.ts`.

## Layout

| Path | Role |
|---|---|
| `entities/{id}.png` | Vessel / enemy spritesheet. Id matches `survivors.json` or `entities.json`. |
| `entities/{id}.json` | Optional sidecar: compact anims **or** a Pixelorama project / Aseprite JSON export. Skip if frames are square and idle is frame 0. |
| `items/{id}.png` | HUD / level-up icon (24px). Id matches `items.json`. |
| `skills/{id}.png` | HUD / hall icon (24px). Id matches `skills.json`. |
| `ui/atlas.png` + `ui/atlas.json` | Shared HUD / menu texture atlas (`logo`, `btn-plaque`, `btn-cta`, `hall-banner`, `parchment-panel`, `pause-tablet`, `pause-inventory`, `hud-objective`, `hud-timer`, `hud-flask`, `hud-skill-dock`, `hud-inventory`, `card-{rarity}`, `portrait-{id}`). Supports 3-state buttons (`idle`, `hover`, `active`) and 9-slice (`nineSlice.margins` + `nineSlice.expandable`). CSS/SVG fallback renders when missing. |
| `env/` | Future authored stage blocks (not random tile stamps). |
| `fx/` | Optional VFX stills. Id matches a skill, a biome spit, or a sim FX kind (`hit`, `dash`, …). |

Do not put biome in the filename. The same Homunculus / mite ships in Cinder and Rime. A different look is a new catalog id with its own sheet.

## Entity sheets

Horizontal strip of equal frames. Phaser loads `entity-{id}` via `load.spritesheet`. Default if the PNG has no sidecar:

- `frameWidth` = `frameHeight` = image height (square cells)
- `idle` = frame 0
- `walk` = every frame at 8 fps, looping (only if there is more than one cell)

Sidecar can be the compact form, a **Pixelorama project JSON** (`size_x` / `size_y` / `fps` / `tags`), or an Aseprite-style spritesheet JSON (`meta.frameTags`). Pixelorama tags are 1-based; Aseprite tags are 0-based. Tag names map to Phaser anims (`idle`, `walk`). Vite bakes that into `manifest.json`.

Compact example:

```json
{
  "frameWidth": 32,
  "frameHeight": 48,
  "anims": {
    "idle": { "frames": [3, 4], "frameRate": 6, "repeat": -1 },
    "walk": { "frames": [0, 1, 2], "frameRate": 6, "repeat": -1 }
  }
}
```

Pixelorama drop-in: export the sheet as `entities/{id}.png` and copy the project JSON next to it as `entities/{id}.json` (tags `idle` / `walk` on the timeline).

Arena `flipX` for left. Player, elites, and bosses are Phaser Sprites (`playEntity`). Fodder uses one `SpriteGPULayer` per entity id; walk frames run on the GPU (`setAnimations`). Non-square frames keep their native size; square vessel sheets still display at 40.

Walk animation playback speed is dynamically linked to real movement speed (`speedRatio = currentSpeed / baseSpeed`):
- Player walk animation and vertical step bobbing scale proportionally with `speedRatio` (reflecting buffs, items like Goat Hoof, or hazard/slow debuffs).
- Elites and bosses scale `sprite.anims.timeScale = speedRatio` when moving and transition to `idle` when stationary, rooted, or dying.
- Fodder on `SpriteGPULayer` scales GPU member cycle `duration = baseDuration / speedRatio`; stationary/rooted/corpse members set `animation = undefined` and show static frame 0.

Procedural fallback sizes: vessel 40, mite 24, spitter 28, elite 40, boss 64, icons 24.

## UI Atlas (`public/sprites/ui/atlas.png` + `atlas.json`)

UI elements are loaded from a single texture atlas (`public/sprites/ui/atlas.png` + `public/sprites/ui/atlas.json`) into `manifest.uiAtlas`.
- **Static elements** (`logo`, `hud-flask`, etc.) define `{ "x", "y", "w", "h" }`.
- **Buttons** (`btn-plaque`, `btn-cta`, etc.) define 3 states (`idle`, `hover`, `active`) either via `states: { idle, hover, active }` or `states: "strip-v"` / `"strip-h"`.
- **9-slice elements** include `nineSlice` with both `margins` (`{ top, right, bottom, left }`) and `expandable` (`{ x, y, w, h }` inner stretch region), rendered via CSS `border-image` so corners stay pixel-sharp at any element size.

## FX stills

Arena loads `manifest.fx` as `fx-{id}` images. Missing PNG keeps the old procedural path (8px `px-bolt-*`, GPU sparks).

Authored FX is drawn **facing +X**. Projectiles rotate with `atan2(vy, vx)` and display at native pixel size (current sheets 32×29). Do not squash or tint an authored shot — the PNG already tells the skill apart.

| Stem | Used for |
|---|---|
| `bolt` / `skill-aether-pierce` / `skill-censer-lob` / `skill-condemn-tether` | Player projectiles (flags pierce / impact / tether) |
| `cinder-spit` / `frost-spit` | Enemy bolts by biome |
| `skill-brimstone-line` / `skill-crucible-cull` | Zone overlay (Graphics telegraph stays) |
| `dash` | `FX_DASH` (Ash Step shares this unless `fx/dash-ash-step.png` exists) |
| `hit` / `hurt` / `death` / `muzzle` / `gem` / `noxious-pop` | Matching `FX_*` stills; GPU sparks only if the PNG is missing |

`reduceVfx` skips stills and spark bursts. No additive blend on the projectile pool.

## Environment Atlas (`public/sprites/env/atlas.png` + `atlas.json`)

Environment art can be authored either via a shared texture atlas (`public/sprites/env/atlas.png` + `public/sprites/env/atlas.json`) or standalone files in `public/sprites/env/{id}.png`.

If a frame has `{ "w": 0, "h": 0 }` or is omitted, the game automatically uses the procedural fallback in `src/view/procedural-pixel-art.ts`.

Themes map per stage: `cinder` (`cinder-yard`), `rime` (`rime-dock`), `glacial` (`glacial-tomb`). Glacial automatically falls back to `rime` if a `glacial-*` prop is missing from the atlas before falling back to procedural.

### Frame keys & recommended dimensions:
- **Floor tiles** (`64×64 px`):
  - Base tiles: `{theme}-tile-0`, `{theme}-tile-1`, `{theme}-tile-2`, `{theme}-tile-3` (variant 0 serves as fallback).
  - Rune tiles: `{theme}-tile-rune-0`, `{theme}-tile-rune-1`, `{theme}-tile-rune-2`, `{theme}-tile-rune-3` (scattered ~12.5% as occult accents).
- **Arena borders (6 pieces)**:
  - Horizontal edges: `{theme}-border-h-0`, `{theme}-border-h-1` (`64×16 px` or `64×32 px` or `64×64 px`).
  - Vertical edges: `{theme}-border-v-0`, `{theme}-border-v-1` (`16×64 px` or `32×64 px` or `64×64 px`).
  - Corners: `{theme}-border-corner-top` (TL & TR), `{theme}-border-corner-bottom` (BL & BR) (`16×16 px` or `32×32 px` or `64×64 px`).
- **Pillars** (`radius: 52` -> `64×64 px` or `104×104 px`): `{theme}-pillar` (`cinder-pillar`, `rime-pillar`, `glacial-pillar`).
- **Hazards** (`radius: 68` -> `64×64 px` or `128×128 px`): `{theme}-hazard-0`, `{theme}-hazard-1` (frame 1 falls back to frame 0).
- **Volatiles** (`radius: 22` -> `32×32 px` or `24×24 px`): `{theme}-volatile` (`cinder-volatile`, `rime-volatile`, `glacial-volatile`).
- **Objectives**: `{theme}-circle` (Transmutation Circle, `160×160 px` or `320×320 px`), `{theme}-portal` (The Rift, `96×96 px` or `140×140 px`).
- **Ambient specks** (`8×8 px` / `16×16 px`): `ambient-ash`, `ambient-ember`, `ambient-snow`, `ambient-mist`.

## Do

Drop a PNG, restart `bun run dev` (or let the watcher rewrite the manifest).

## Don't

Generate art in-repo. Keep `_ref` / `_in` / `_raw` / Comfy. Atlas packs (use a spritesheet). Hue-shift one enemy into another biome — add a catalog row instead.
