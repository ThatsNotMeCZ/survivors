# ComfyUI sprites

Local SDXL pipeline. Character **refs** go to `_ref/` for an external sprite generator. Game **icons** (and env plates) go straight into `public/sprites/` at catalog size. Procedural canvases stay the fallback for everything else (fodder, walk, VFX).

ComfyUI lives at `~/ComfyUI`, API `http://127.0.0.1:8188` (`COMFYUI_HOME` / `COMFYUI_URL` override).

Comfy generates **only**:

- vessel **front** identity refs → `public/sprites/_ref/{key}.png` at **512px**
- **icons** (hall portraits, item pickups) → `public/sprites/{key}.png` at catalog size
- **env** plates when those entries exist

Not generated: enemy bodies, side/back, walk cycles, game-size player sprites. Drop those PNGs into `public/sprites/` yourself (or let the external generator write them from `_ref/`).

```bash
bun run art:comfy                    # ~/ComfyUI on 127.0.0.1:8188
bun run art:ref -- runner            # Homunculus front → public/sprites/_ref/ (512px)
bun run art:ref -- penitent
bun run art:item -- glass-cannon     # 24px HUD icon
bun run art:generate                 # missing refs + icons (skip existing)
bun run art:generate -- --force      # overwrite
bun run art:list
```

`--force` overwrites an existing PNG at the destination. Existing files are skipped otherwise.

Refs are not loaded by the game. `ArenaScene.preload` only reads `sprites/manifest.json` keys under `public/sprites/*.png`.

## Stack

Native nodes only. Workflow: `tools/comfy/workflows/sprite-txt2img-api.json`.

| Role | File | Where |
|---|---|---|
| Checkpoint | `juggernautXL_ragnarok.safetensors` | `models/checkpoints/` |
| LoRA | `pixel-art-xl.safetensors` (NeriJS / Civitai 120096) | `models/loras/` |

LoRA weight 1.0. Generate 1024² → nearest-exact (refs **512²**, icons **128²**) → chroma-key white → crop-to-fit. Refs use 32 sampler steps and `refStyleSuffix` in `tools/comfy/sprites.json`. Icons crop to catalog `size`. Prompts: `tools/comfy/sprites.json` (`kind`: `front` | `icon` | `env`).

Restart ComfyUI after new model files land (`bun run art:comfy`). `CIVITAI_TOKEN` only if Hugging Face is blocked.

This machine already has SDXL checkpoints in `~/ComfyUI/models/checkpoints/`. Swap `checkpoint` in `models.json` if needed.

## In game

`ArenaScene.preload` loads `sprites/manifest.json` then those PNGs under the same `px-*` keys. Missing keys use procedural art. Player displays at 40px. Hall uses the front idle PNG from `public/sprites/`, not `_ref/`. HUD / level-up read `sprites/px-item-{id}.png` from HTML.

Keep game sprites at catalog size (player 40, icons 24). High-detail character art belongs in `_ref/` as identity for the external generator, not in the arena.
