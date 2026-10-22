# Sprites

Drop finished art into `public/sprites/`. Vite rewrites `manifest.json` on `dev` / `build` by scanning folders. Missing entity sheets fall back to procedural canvases in `src/view/procedural-pixel-art.ts`.

## Layout

| Path | Role |
|---|---|
| `entities/{id}.png` | Vessel / enemy spritesheet. Id matches `survivors.json` or `entities.json`. |
| `entities/{id}.json` | Optional frame size + anims. Skip if frames are square and idle is frame 0. |
| `items/{id}.png` | HUD / level-up icon (24px). Id matches `items.json`. |
| `skills/{id}.png` | HUD / hall icon (24px). Id matches `skills.json`. |
| `env/` | Future authored stage blocks (not random tile stamps). |
| `fx/` | Optional VFX stills. Hit sparks stay GPU procedural until a PNG lands. |

Do not put biome in the filename. The same Homunculus / mite ships in Cinder and Rime. A different look is a new catalog id with its own sheet.

## Entity sheets

Horizontal strip of equal frames. Phaser loads `entity-{id}` via `load.spritesheet`. Default if the PNG has no sidecar:

- `frameWidth` = `frameHeight` = image height (square cells)
- `idle` = frame 0
- `walk` = every frame at 8 fps, looping (only if there is more than one cell)

Sidecar example (`entities/runner.json`):

```json
{
  "frameWidth": 40,
  "frameHeight": 40,
  "anims": {
    "idle": { "frames": [0], "frameRate": 1, "repeat": -1 },
    "walk": { "frames": [1, 2, 3], "frameRate": 8, "repeat": -1 }
  }
}
```

Arena `flipX` for left. Player, elites, and bosses are Phaser Sprites (`play('entity-{id}-walk')`). Fodder uses one `SpriteGPULayer` per entity id; walk frames run on the GPU (`setAnimations`).

Catalog sizes: vessel 40, mite 24, spitter 28, elite 40, boss 64, icons 24.

## Environment (later)

Stages still stamp a procedural floor and scatter pillars / hazards / volatiles. Next step is authored **blocks** in `env/` placed as layout chunks, not a new biome recolor of the same mesh.

## Do

Drop a PNG, restart `bun run dev` (or let the watcher rewrite the manifest).

## Don't

Generate art in-repo. Keep `_ref` / `_in` / `_raw` / Comfy. Atlas packs (use a spritesheet). Hue-shift one enemy into another biome — add a catalog row instead.
