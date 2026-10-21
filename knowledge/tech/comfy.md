# ComfyUI sprites

Local SDXL pipeline. Character **refs** go to `_ref/` at native 1024px (later downscale to game size). Item and skill icons are **2-step**: 1024px into `_ref/items/` or `_ref/skills/`, then local downsample to catalog 24px. Hall portraits (and env plates) go straight into `public/sprites/` at catalog size. Procedural canvases stay the fallback for everything else (fodder, VFX).

ComfyUI lives at `~/ComfyUI`, API `http://127.0.0.1:8188` (`COMFYUI_HOME` / `COMFYUI_URL` override).

Comfy generates **only**:

- one vessel **front** idle ref → `public/sprites/_ref/px-player-body-{vessel}-cinder-front.png` at **1024px**
- **walk** frames → `public/sprites/_ref/px-player-body-{vessel}-cinder-walk-side-{0|1|2}.png` at **1024px** (img2img from the idle + ControlNet OpenPose)
- **item** refs → `public/sprites/_ref/items/{id}.png` at **1024px**, then crop-to-fit **24px** → `public/sprites/px-item-{id}.png`
- **skill** refs → `public/sprites/_ref/skills/{id}.png` at **1024px**, then crop-to-fit **24px** → `public/sprites/px-skill-{id}.png`
- **portraits** (hall) → `public/sprites/{key}.png` at catalog size
- **env** plates when those entries exist

Not generated: extra views, enemy bodies, game-size player sprites. Drop external idle/walk sheets in `public/sprites/_in/` (`runner_idle.jpeg`, `runner_walk.jpeg`). `bun run art:slice` crops figures → `_raw/` + `_ref/` (1024px) + `public/sprites/` (40px). Runner idle is the **side** stand (`px-player-body-runner-cinder-side`); walk is `-walk-side-{0|1|2}`. Arena `flipX` for left. Until walk PNGs exist in `public/sprites/`, moving reuses idle.

```bash
bun run art:comfy                    # ~/ComfyUI on 127.0.0.1:8188
bun run art:ref -- runner            # Homunculus front idle → public/sprites/_ref/ (1024px)
bun run art:walk -- runner           # 3 walk frames via ControlNet OpenPose (needs idle first)
bun run art:ref -- penitent
bun run art:item-ref -- glass-cannon # 1024px only → public/sprites/_ref/items/
bun run art:item-ref                 # all missing item refs
bun run art:item -- glass-cannon     # 1024px _ref/items/ + 24px HUD icon
bun run art:item                     # all missing item refs + icons
bun run art:item -- --force          # overwrite all 13 (ref + icon)
bun run art:item -- glass-cannon --from-ref  # 24px from an existing 1024 ref
bun run art:skill-ref -- bolt        # 1024px only → public/sprites/_ref/skills/
bun run art:skill-ref                # all missing skill refs
bun run art:skill -- bolt            # 1024px _ref/skills/ + 24px HUD icon
bun run art:skill                    # all missing skill refs + icons
bun run art:skill -- --force         # overwrite all 8 (ref + icon)
bun run art:skill -- bolt --from-ref # 24px from an existing 1024 ref
bun run art:generate                 # missing refs + icons (skip existing)
bun run art:generate -- --force      # overwrite
bun run art:slice                    # crop _in/runner_{idle,walk}.jpeg → _ref 1024 + 40px game
bun run art:list
```

`--force` overwrites an existing PNG (`art:item` / `art:skill`: both the 1024 ref and the 24px icon; `art:item-ref` / `art:skill-ref`: the 1024 ref only). Existing files are skipped otherwise. If the object ref exists and the 24px icon does not, `art:item` / `art:skill` downsamples without calling Comfy. `--from-ref` never calls Comfy. `--item-ref` / `--skill-ref` / `--ref-only` never writes the 24px icon.

Item and skill prompts name a **concrete object** (vial, fire-needle, censer), not the display name or lore. Visual target for item objects: `public/sprites/_in/items-sheet.jpeg` (not an img2img input).

Refs are not loaded by the game. `ArenaScene.preload` only reads `sprites/manifest.json` keys under `public/sprites/*.png`.

## Stack

Idle refs are native txt2img (front view only). Walk frames are img2img from that idle plus ControlNet OpenPose. Workflows: `tools/comfy/workflows/sprite-txt2img-api.json` (vessel idle, items, skills, portraits), `sprite-walk-controlnet-api.json` (walk).

| Role | File | Where |
|---|---|---|
| Checkpoint | `juggernautXL_ragnarok.safetensors` | `models/checkpoints/` |
| LoRA | `pixel-art-xl.safetensors` (NeriJS / Civitai 120096) | `models/loras/` |
| ControlNet | `controlnet-openpose-sdxl.safetensors` (xinsir OpenPose SDXL) | `models/controlnet/` |

LoRA weight 1.0. Generate 1024². Character, item, and skill refs skip Comfy `ImageScale` and keep an **opaque white** 1024² plate (no chroma-key, no crop). Game-size item/skill icons still chroma-key white then crop-to-fit catalog `size`. Portraits nearest-exact **128²** then crop to catalog `size`. Refs use 32 sampler steps. Style: `refStyleSuffix` (vessels), `itemStyleSuffix` (items), `skillStyleSuffix` (skills), `styleSuffix` (portraits). Prompts: `tools/comfy/sprites.json` (`kind`: `ref` | `walk` | `icon` | `env`; idle refs have `view`: `front`; walk has `view`: `side`, `frame`, `from`; items have `item`; skills have `skill`). Walk uses denoise 0.55 and ControlNet strength 0.72 (`models.json`).

Restart ComfyUI after new model files land (`bun run art:comfy`). `CIVITAI_TOKEN` only if Hugging Face is blocked.

This machine already has SDXL checkpoints in `~/ComfyUI/models/checkpoints/`. Swap `checkpoint` in `models.json` if needed.

## In game

`ArenaScene.preload` loads `sprites/manifest.json` then those PNGs under the same `px-*` keys. Missing keys use procedural art. Player displays at 40px. Homunculus idle is the **side** PNG (`px-player-body-runner-{biome}-side`) with `flipX` for left; The Penitent still uses **front**. Hall prefers side, then front, then the portrait icon. HUD / level-up read `sprites/px-item-{id}.png` from HTML. HUD skill slots and hall kit read `sprites/px-skill-{id}.png` (Roman-numeral glyph if the PNG is missing).

Keep game sprites at catalog size (player 40, icons 24). High-detail character art belongs in `_ref/` (1024px). Item refs live in `_ref/items/` and skill refs in `_ref/skills/` (1024px) and downsample to 24px HUD icons. External vessel sheets slice to game size via `art:slice`.
