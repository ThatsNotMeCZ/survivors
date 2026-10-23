# Sprites

Drop finished art into `public/sprites/`. Vite rewrites `manifest.json` on `dev` / `build` by scanning folders. Missing entity sheets fall back to procedural canvases in `src/view/procedural-pixel-art.ts`.

## Layout

| Path | Role |
|---|---|
| `entities/{id}.png` | Vessel / enemy spritesheet. Id matches `survivors.json` or `entities.json`. |
| `entities/{id}.json` | Optional sidecar: compact anims **or** a Pixelorama project / Aseprite JSON export. Skip if frames are square and idle is frame 0. |
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

Arena `flipX` for left. Player, elites, and bosses are Phaser Sprites (`play('entity-{id}-walk')`). Fodder uses one `SpriteGPULayer` per entity id; walk frames run on the GPU (`setAnimations`). Non-square frames keep their native size; square vessel sheets still display at 40.

Procedural fallback sizes: vessel 40, mite 24, spitter 28, elite 40, boss 64, icons 24.

## Environment (later)

Stages still stamp a procedural floor and scatter pillars / hazards / volatiles. Next step is authored **blocks** in `env/` placed as layout chunks, not a new biome recolor of the same mesh.

## Do

Drop a PNG, restart `bun run dev` (or let the watcher rewrite the manifest).

## Don't

Generate art in-repo. Keep `_ref` / `_in` / `_raw` / Comfy. Atlas packs (use a spritesheet). Hue-shift one enemy into another biome — add a catalog row instead.
