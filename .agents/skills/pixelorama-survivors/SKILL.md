---
name: pixelorama-survivors
description: >
  Draw, edit, and export Hermetic Rifts pixel art through Pixelorama MCP
  (namespace pixelorama-mcp): sprites, .pxo projects, Resurrect 64 + black,
  draw_pixels_fast stride-3 patches, idle/walk/attack-* tags. Use when
  creating or changing entity/item/skill/fx/env sprites, opening a .pxo,
  or the user mentions Pixelorama, pixel art, spritesheets, or palette.
---

# Pixelorama Survivors

Authored pixel art for Hermetic Rifts. MCP namespace `pixelorama-mcp`. Inspect the tool schema before each call. Do not Write binary PNGs.

Tool matrix, batch limits, and anti-patterns: [references/mcp-cheatsheet.md](references/mcp-cheatsheet.md). Frame sizes, tags, export: [knowledge/tech/pixelorama-mcp.md](../../../knowledge/tech/pixelorama-mcp.md). Palette file: [tools/pixelorama/resurrect-64.pal](../../../tools/pixelorama/resurrect-64.pal) — fetch swatches with `get_palette_colors`, do not paste all 64 hex into prompts.

## Hard constraints

- Sprites nemají velké single-color bloky, většina v sobě má "šum" a to je potřeba zachovat i pro agent úpravy
- Agent může používat pouze paletu Resurrect 64 + black

Outline and dark lines are `#000000`. Do not use `#120a0d`. Do not invent hex outside Resurrect 64 + black.

## Session bootstrap

Minimum calls. Do not dump the whole canvas into context.

1. `open_project` with the absolute filesystem path to `tools/pixelorama/{id}.pxo` when that file exists. Never `create_canvas` over an existing project.
2. `list_palettes` if the active name is unknown, then `switch_palette` to Resurrect 64. `set_color` only from that palette or `#000000`.
3. `describe_canvas` once on first open, or after changing frame / tag. Later: `get_canvas_info`.

If tools time out or `:7373` is down, print the checklist in `knowledge/tech/pixelorama-mcp.md` and stop.

## Edit existing art

Keep every pixel outside the change bbox.

1. Tight bbox from the brief, or `validate_sprite` bounding box on the target frame.
2. `get_region` **only that bbox** (never the full frame unless the edit is the whole cell). Read existing hex and neighboring shades from the matrix.
3. Patch with `draw_pixels_fast` stride 3: `[x, y, '#hex', ...]`. Fills: rotate 2–4 **adjacent** palette colors from the region. Do not put one hex on a region larger than 3×3 without a reason (eye, outline, UI chrome).
4. Animation: `copy_cel` for unchanged parts; change only the delta (legs, jaw, FX) on later frames.
5. Touching a pixel that is still `#120a0d`: rewrite that pixel to `#000000` or the nearest Resurrect 64 color. Do not run a canvas-wide remap.

**Forbidden on entity / item / skill / fx sheets:** `fill_area`, large `draw_rect`, `apply_gradient` on whole shapes, `color_replace` of a body color, `remap_to_palette`, `clean_isolated_pixels` (eats noise), `generate_sprite` without a region read.

## New sprite

1. Silhouette, then 1px `#000000` outline.
2. Body in 3–5 px clusters, rotating 2–3 palette shades (not flat fills).
3. Frame sizes and 1-based tags (`idle`, `walk`, `attack` / `attack-*`): `knowledge/tech/pixelorama-mcp.md`. Creature faces **right**.

## Exceptions (flat fill OK)

- Procedural env tiles in `tools/pixelorama/world.pxo` via `eval_gdscript` (never for Godot game scripts).
- UI chrome in `button.pxo` / `gui*.pxo` only when the brief says flat.

## QA then ship

One batch on the frames you touched:

1. `validate_sprite` (`check_holes`, `check_orphans`).
2. `get_palette_usage` — unique colors must be Resurrect 64 + `#000000` only.
3. One `capture_canvas_image` (magnify the bbox; crop with `x,y,width,height`).
4. `save_project` → `export_image` → `./tools/pixelorama/publish-sprite.sh <kind> <id>`.

There is no MCP publish tool. Do not export until QA passes.
