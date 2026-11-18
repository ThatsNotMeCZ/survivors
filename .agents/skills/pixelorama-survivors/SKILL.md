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

## New sprite or UI component

Never improvise raw geometric primitives (`draw_rect`, unshaded circles, 1px stick icons). Follow this pipeline:

1. **Study siblings first (mandatory):** Inspect 1–2 completed assets of the same kind (`capture_canvas_image` on a sibling frame + `get_region` on a small 24×24 corner/detail sample). In `gui_agent.pxo`, study `hud-skill-dock`, `hud-inventory`, `btn-plaque`, and `parchment-panel` before designing any HUD element. Extract the exact Resurrect 64 material ramps, border thickness, corner ornaments, and detail density.
2. **Plan in memory before drawing:** Define silhouette, top-left light direction, 3–4 value ramps per material (`#000000` outline → shadow → midtone → highlight), focal icon/motif, and cast shadows.
3. **Pixel-art hygiene:** Avoid jagged 1px stair-steps ("jaggies"), accidental 2px curve "doubles", and pillow shading. Use clean 2–3px segment curves and 1px `#000000` outer silhouettes.
4. **Entities / items / FX:** Silhouette + 1px `#000000` outline → body in 3–5 px clusters rotating 2–3 adjacent palette shades (not flat fills). Frame sizes and 1-based tags (`idle`, `walk`, `attack` / `attack-*`): `knowledge/tech/pixelorama-mcp.md`. Creature faces **right**.
5. **UI chrome (`gui*.pxo`, `button.pxo`):**
   - Multi-stop beveled frame (5–8px total border depth: 1px `#000000` outer outline → top/left highlight & bottom/right shadow bevel → midtone dark iron/stone/brass body with chamfered/notched corners, rivets, or filigree → 1px dark inner recess lip).
   - Embedded icons (compass/astrolabe, timer dial, flask, runes) must be full miniature pixel-art pieces with 1px `#000000` outline, 3–4 tone shading, specular glint, and a 1–2px cast shadow onto the frame behind them.
   - Respect 9-slice margins if the component is 9-sliced in `atlas.json` (ornaments stay in corners/edges, stretchable center stays clean).

## Exceptions (flat fill OK)

- Procedural env tiles in `tools/pixelorama/world.pxo` via `eval_gdscript` (never for Godot game scripts).
- Only the **inner stretchable 9-slice content well** of a UI panel may be a uniform dark slate/parchment fill (with subtle corner vignette/edge weathering); frames, borders, corners, dividers, and icons are **never** flat.

## QA then ship

On the frames you touched:

1. `validate_sprite` (`check_holes`, `check_orphans`).
2. `get_palette_usage` — unique colors must be Resurrect 64 + `#000000` only.
3. **Visual QA Gate:** `capture_canvas_image` (magnified crop `x,y,width,height`, `scale` 4–8) and compare directly against the sibling studied in step 1:
   - Does it match the sibling's craft, material ramps, and detail density (not MS-Paint / programmer art)?
   - Are borders beveled/ornate and top-left lit (not a flat 1px box)?
   - Do embedded icons have `#000000` outlines, multi-tone shading, and cast shadows?
   - Is surface noise/weathering present without hurting readability?
   If **any** check fails, fix it and re-capture (up to 3–4 captures for new art; 1–2 for small edits).
4. Only after visual QA passes: `save_project` → `export_image` → `./tools/pixelorama/publish-sprite.sh <kind> <id>` (or `python3 tools/pixelorama/pack_ui_atlas_from_gui.py` for `gui_agent.pxo`).

There is no MCP publish tool. Do not export until QA passes.
